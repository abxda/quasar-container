#!/bin/bash
# =============================================================================
# install-stack.sh — Instalación del stack Quasar MULTI-ARCH (arm64 + amd64)
# =============================================================================
# Adaptación del original quasar-packer-build/scripts/20-quasar-stack.sh.
# Cambios respecto al original:
#   * Elasticsearch se baja en el build que corresponde a la arquitectura
#     (aarch64 en Mac ARM, x86_64 en Windows/Linux Intel) — detección automática.
#   * JAVA_HOME usa el symlink estable /usr/lib/jvm/java-17-current (creado en el
#     Dockerfile) en vez de fijar la arquitectura.
#   * El usuario de servicio es 'quasar'. Se ejecuta durante el build.
# =============================================================================
set -e
echo "--- [Quasar] Instalando el Stack de Big Data (multi-arch) ---"

INSTALL_DIR="/opt/bdpv5"
DOWNLOAD_DIR="/opt/downloads"
mkdir -p "${INSTALL_DIR}" "${DOWNLOAD_DIR}"

: "${HADOOP_VERSION:=3.3.6}"
: "${KAFKA_SCALA:=2.13}"
: "${KAFKA_VERSION:=4.0.0}"
: "${ES_VERSION:=8.14.1}"
export JAVA_HOME="/usr/lib/jvm/java-17-current"

# --- Detección de arquitectura para Elasticsearch ---
# dpkg devuelve 'arm64' o 'amd64'; Elastic publica 'aarch64' o 'x86_64'.
DEB_ARCH="$(dpkg --print-architecture)"
case "${DEB_ARCH}" in
  arm64) ES_ARCH="aarch64" ;;
  amd64) ES_ARCH="x86_64"  ;;
  *) echo "Arquitectura no soportada: ${DEB_ARCH}" >&2; exit 1 ;;
esac
echo "-> Arquitectura detectada: ${DEB_ARCH} (Elasticsearch=${ES_ARCH})"

echo "-> Paso 1/7: Descargando binarios..."
# Hadoop y Kafka son tarballs Java => mismos artefactos para todas las arquitecturas.
wget -q -P "${DOWNLOAD_DIR}" "https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
wget -q -P "${DOWNLOAD_DIR}" "https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${KAFKA_SCALA}-${KAFKA_VERSION}.tgz"
# Elasticsearch SÍ es específico de arquitectura.
wget -q -P "${DOWNLOAD_DIR}" "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}-linux-${ES_ARCH}.tar.gz"

echo "-> Paso 2/7: Extrayendo y enlazando..."
tar -xzf "${DOWNLOAD_DIR}/hadoop-${HADOOP_VERSION}.tar.gz" -C "${INSTALL_DIR}"
ln -sfn "${INSTALL_DIR}/hadoop-${HADOOP_VERSION}" "${INSTALL_DIR}/hadoop"
tar -xzf "${DOWNLOAD_DIR}/kafka_${KAFKA_SCALA}-${KAFKA_VERSION}.tgz" -C "${INSTALL_DIR}"
ln -sfn "${INSTALL_DIR}/kafka_${KAFKA_SCALA}-${KAFKA_VERSION}" "${INSTALL_DIR}/kafka"
tar -xzf "${DOWNLOAD_DIR}/elasticsearch-${ES_VERSION}-linux-${ES_ARCH}.tar.gz" -C "${INSTALL_DIR}"
ln -sfn "${INSTALL_DIR}/elasticsearch-${ES_VERSION}" "${INSTALL_DIR}/elasticsearch"

echo "-> Paso 3/7: Variables de entorno globales..."
cat <<'EOF' > /etc/profile.d/bdpv5_env.sh
export JAVA_HOME="/usr/lib/jvm/java-17-current"
export BDPV5_ROOT="/opt/bdpv5"
export HADOOP_HOME="$BDPV5_ROOT/hadoop"
export KAFKA_HOME="$BDPV5_ROOT/kafka"
export ES_HOME="$BDPV5_ROOT/elasticsearch"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export PATH="$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$KAFKA_HOME/bin:$ES_HOME/bin:$BDPV5_ROOT/python/bin:$PATH"
export PYSPARK_PYTHON="$BDPV5_ROOT/python/bin/python"
export PYSPARK_DRIVER_PYTHON="$BDPV5_ROOT/python/bin/python"
EOF

echo "-> Paso 4/7: Configuración de servicios..."
HADOOP_CONF_DIR="${INSTALL_DIR}/hadoop/etc/hadoop"
echo '<configuration><property><name>fs.defaultFS</name><value>hdfs://localhost:9000</value></property></configuration>' > "${HADOOP_CONF_DIR}/core-site.xml"
echo '<configuration><property><name>dfs.replication</name><value>1</value></property><property><name>dfs.namenode.name.dir</name><value>file:///opt/bdpv5/data/hdfs/namenode</value></property><property><name>dfs.datanode.data.dir</name><value>file:///opt/bdpv5/data/hdfs/datanode</value></property></configuration>' > "${HADOOP_CONF_DIR}/hdfs-site.xml"
{
  echo "export JAVA_HOME=${JAVA_HOME}"
  echo 'export HADOOP_OPTS="$HADOOP_OPTS --add-opens=java.base/java.lang=ALL-UNNAMED"'
} >> "${HADOOP_CONF_DIR}/hadoop-env.sh"

KAFKA_CONFIG_DIR="${INSTALL_DIR}/kafka/config/kraft"
mkdir -p "${KAFKA_CONFIG_DIR}"
cat <<'EOF' > "${KAFKA_CONFIG_DIR}/server.properties"
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@localhost:9093
listeners=PLAINTEXT://:9092,CONTROLLER://:9093
advertised.listeners=PLAINTEXT://localhost:9092
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
log.dirs=/opt/bdpv5/data/kafka_kraft
# Broker único (KRaft): los topics internos deben tener RF=1, si no, el
# coordinador de grupos no arranca y el consumo POR GRUPO se cuelga
# (__consumer_offsets intentaría RF=3 sin réplicas disponibles).
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
EOF

ES_CONFIG="${INSTALL_DIR}/elasticsearch/config/elasticsearch.yml"
# IMPORTANTE: NO se activa bootstrap.memory_lock (incompatible con rootless
# Podman). discovery.type=single-node degrada los bootstrap checks a warnings.
{
  echo 'network.host: 0.0.0.0'
  echo 'xpack.security.enabled: false'
  echo 'discovery.type: single-node'
  echo 'bootstrap.memory_lock: false'
} > "${ES_CONFIG}"

echo "-> Paso 5/7: Entorno Python + librerías..."
python3 -m venv "${INSTALL_DIR}/python"
"${INSTALL_DIR}/python/bin/pip" install --no-cache-dir --upgrade pip
"${INSTALL_DIR}/python/bin/pip" install --no-cache-dir jupyterlab pyspark hdfs "elasticsearch==8.14.0"

echo "-> Paso 6/7: Permisos + formateo de HDFS y Kafka..."
mkdir -p "${INSTALL_DIR}/data/hdfs/namenode" "${INSTALL_DIR}/data/hdfs/datanode" \
         "${INSTALL_DIR}/data/kafka_kraft" "${INSTALL_DIR}/logs"
chown -R quasar:quasar "${INSTALL_DIR}"

su - quasar -c "${INSTALL_DIR}/hadoop/bin/hdfs namenode -format -force -nonInteractive"
KAFKA_CLUSTER_ID="$(su - quasar -c "${INSTALL_DIR}/kafka/bin/kafka-storage.sh random-uuid")"
su - quasar -c "${INSTALL_DIR}/kafka/bin/kafka-storage.sh format -t '${KAFKA_CLUSTER_ID}' -c '${KAFKA_CONFIG_DIR}/server.properties'"

echo "-> Paso 7/7: Limpieza..."
rm -rf "${DOWNLOAD_DIR}"
echo "--- [Quasar] Stack instalado (${DEB_ARCH}) ---"
