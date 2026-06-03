#!/bin/bash
# quasar-start.sh — inicia todo el stack (adaptado para el contenedor arm64)
echo "================ INICIANDO STACK QUASAR ================"
source /etc/profile.d/bdpv5_env.sh

# SSH local (Hadoop lo necesita aunque usemos --daemon directo)
service ssh start 2>/dev/null || sudo service ssh start 2>/dev/null || true

run_as_quasar() { su - quasar -c "source /etc/profile.d/bdpv5_env.sh; $1"; }

# Limpieza de PIDs obsoletos
rm -f /tmp/hadoop-quasar-*.pid 2>/dev/null || true

echo "Iniciando HDFS (NameNode, DataNode, SecondaryNameNode)..."
run_as_quasar "/opt/bdpv5/hadoop/bin/hdfs --daemon start namenode"
run_as_quasar "/opt/bdpv5/hadoop/bin/hdfs --daemon start datanode"
run_as_quasar "/opt/bdpv5/hadoop/bin/hdfs --daemon start secondarynamenode"

echo "Iniciando Kafka..."
run_as_quasar "/opt/bdpv5/kafka/bin/kafka-server-start.sh -daemon /opt/bdpv5/kafka/config/kraft/server.properties"

echo "Iniciando Elasticsearch..."
run_as_quasar "ES_JAVA_OPTS='${ES_JAVA_OPTS:--Xms512m -Xmx512m}' /opt/bdpv5/elasticsearch/bin/elasticsearch -d"

echo "Iniciando Jupyter Lab..."
run_as_quasar "/opt/bdpv5/python/bin/jupyter lab --port=8888 --notebook-dir=/home/quasar/work --ip=0.0.0.0 --no-browser --ServerApp.token='' >/opt/bdpv5/logs/jupyter.log 2>&1 &"

echo "================ STACK INICIADO ================"
