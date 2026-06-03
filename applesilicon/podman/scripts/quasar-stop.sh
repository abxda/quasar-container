#!/bin/bash
# quasar-stop.sh — detiene el stack de forma ordenada
echo "================ DETENIENDO STACK QUASAR ================"
source /etc/profile.d/bdpv5_env.sh
run_as_quasar() { su - quasar -c "source /etc/profile.d/bdpv5_env.sh; $1"; }

echo "Deteniendo Jupyter Lab..."
pkill -f jupyter-lab || true

echo "Deteniendo Elasticsearch..."
ES_PID=$(ps aux | grep '[e]lasticsearch' | awk '{print $2}')
[ -n "$ES_PID" ] && kill -9 $ES_PID 2>/dev/null || true

echo "Deteniendo Kafka..."
run_as_quasar "/opt/bdpv5/kafka/bin/kafka-server-stop.sh" || true

echo "Deteniendo HDFS..."
run_as_quasar "/opt/bdpv5/hadoop/bin/hdfs --daemon stop secondarynamenode" || true
run_as_quasar "/opt/bdpv5/hadoop/bin/hdfs --daemon stop datanode" || true
run_as_quasar "/opt/bdpv5/hadoop/bin/hdfs --daemon stop namenode" || true

echo "================ STACK DETENIDO ================"
