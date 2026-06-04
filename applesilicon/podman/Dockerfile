# =============================================================================
# QUASAR BIG DATA LAB — Imagen MULTI-ARCH (arm64 + amd64)
# =============================================================================
# Reemplaza la "Golden Image" .box de VirtualBox (x86_64) por una imagen de
# contenedor que corre NATIVA tanto en Mac Apple Silicon (arm64) como en
# Windows/Linux x86_64 (amd64) — la portabilidad de cohorte mixta.
#
# Construye igual con Podman (recomendado, rootless, Apache 2.0) o Docker:
#   podman compose build     |     docker compose build
#
# Replica fielmente el stack del proyecto Quasar original:
#   - Debian 11 (Bullseye)      - Hadoop 3.3.6
#   - OpenJDK 17                - Kafka 4.0.0 (modo KRaft)
#   - Elasticsearch 8.14.1      - Python venv + JupyterLab/PySpark/hdfs/elasticsearch
#
# Multi-arch: NO se fija la arquitectura. Java y Elasticsearch se resuelven en
# tiempo de build según la plataforma destino (dpkg --print-architecture):
#   * JAVA_HOME -> symlink estable /usr/lib/jvm/java-17-current (apunta a
#     java-17-openjdk-{arm64|amd64}).
#   * Elasticsearch -> build aarch64 o x86_64 según corresponda.
#   * Hadoop/Kafka/PySpark/Jupyter son Java/Python puros => mismos artefactos.
#   * Hadoop NO trae libs nativas para arm64 => WARNING inofensivo (fallback Java).
# =============================================================================

# debian:11 es multi-arch; con `--platform` Podman/Docker elige arm64 o amd64.
FROM debian:11-slim

LABEL maintainer="Dr. Coronado (abxda)"
LABEL description="Quasar Big Data Lab - multi-arch (arm64+amd64) container"

# --- Versiones del stack (centralizadas) ---
ARG HADOOP_VERSION=3.3.6
ARG KAFKA_SCALA=2.13
ARG KAFKA_VERSION=4.0.0
ARG ES_VERSION=8.14.1

# JAVA_HOME apunta a un symlink ESTABLE e independiente de la arquitectura.
ENV DEBIAN_FRONTEND=noninteractive \
    JAVA_HOME=/usr/lib/jvm/java-17-current \
    BDPV5_ROOT=/opt/bdpv5 \
    HADOOP_HOME=/opt/bdpv5/hadoop \
    KAFKA_HOME=/opt/bdpv5/kafka \
    ES_HOME=/opt/bdpv5/elasticsearch \
    HADOOP_CONF_DIR=/opt/bdpv5/hadoop/etc/hadoop \
    ES_JAVA_OPTS="-Xms512m -Xmx512m"
ENV PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$KAFKA_HOME/bin:$ES_HOME/bin:$BDPV5_ROOT/python/bin:$PATH

# --- Fase 1: herramientas base + Java 17 + SSH (Hadoop lo necesita en localhost) ---
# El symlink java-17-current absorbe la diferencia arm64/amd64 para todo el stack.
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        curl wget lsof git ca-certificates procps \
        openjdk-17-jdk \
        python3-pip python3-venv \
        openssh-server openssh-client && \
    ln -sfn "/usr/lib/jvm/java-17-openjdk-$(dpkg --print-architecture)" /usr/lib/jvm/java-17-current && \
    rm -rf /var/lib/apt/lists/*

# --- Usuario no-root 'quasar' (Elasticsearch se niega a correr como root) ---
RUN useradd -m -s /bin/bash quasar && \
    mkdir -p ${BDPV5_ROOT} && chown -R quasar:quasar ${BDPV5_ROOT}

# --- Fase 2: instalar el stack de Big Data (script multi-arch) ---
COPY scripts/install-stack.sh /tmp/install-stack.sh
RUN chmod +x /tmp/install-stack.sh && \
    HADOOP_VERSION=${HADOOP_VERSION} KAFKA_SCALA=${KAFKA_SCALA} \
    KAFKA_VERSION=${KAFKA_VERSION} ES_VERSION=${ES_VERSION} \
    /tmp/install-stack.sh && \
    rm -f /tmp/install-stack.sh

# --- Scripts de control (start/stop/check) + entrypoint ---
COPY scripts/quasar-start.sh scripts/quasar-stop.sh scripts/quasar-check.sh scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/quasar-start.sh /usr/local/bin/quasar-stop.sh \
             /usr/local/bin/quasar-check.sh /usr/local/bin/entrypoint.sh

# --- Llaves SSH para que Hadoop alcance localhost sin password ---
RUN su - quasar -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
        ssh-keygen -t rsa -f ~/.ssh/id_rsa -N '' && \
        cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
        chmod 600 ~/.ssh/authorized_keys"

# --- Fix Kafka KRaft (broker único) ---
# En un solo broker, los topics internos de Kafka (__consumer_offsets y los de
# estado de transacciones) usan por defecto factor de replicación 3, imposible
# de satisfacer con un nodo: el coordinador de grupo nunca queda listo y todo
# consumo por grupo (p.ej. kafka-console-consumer, clientes con group.id) se
# CUELGA con TimeoutException. Forzamos RF=1 e ISR=1 para single-node. Se hace
# como paso propio (no en install-stack.sh) para preservar el caché de la capa
# de descarga del stack; el resultado en runtime es idéntico: estas 3 líneas
# quedan en el server.properties de KRaft que arranca el contenedor.
RUN printf 'offsets.topic.replication.factor=1\ntransaction.state.log.replication.factor=1\ntransaction.state.log.min.isr=1\n' \
        >> /opt/bdpv5/kafka/config/kraft/server.properties

# Puertos: JupyterLab, HDFS NameNode UI, HDFS RPC, Elasticsearch, Kafka
EXPOSE 8888 9870 9000 9200 9092

VOLUME ["/home/quasar/work"]
WORKDIR /home/quasar/work

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
