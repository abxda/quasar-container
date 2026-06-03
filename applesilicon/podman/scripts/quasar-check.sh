#!/bin/bash
# quasar-check.sh — resumen del estado de los servicios
echo "================ VERIFICANDO ESTADO DEL STACK ================"
source /etc/profile.d/bdpv5_env.sh
echo "--- Procesos Java (jps) ---"
su - quasar -c "source /etc/profile.d/bdpv5_env.sh; jps -l"
echo ""
echo "--- Verificación por Servicio ---"
JPS="$(su - quasar -c 'source /etc/profile.d/bdpv5_env.sh; jps')"
echo "$JPS" | grep -q "NameNode" && echo "$JPS" | grep -q "DataNode" && echo "✅ HDFS: NameNode y DataNode ACTIVOS." || echo "❌ HDFS: procesos no detectados."
echo "$JPS" | grep -q "Kafka" && echo "✅ Kafka: ACTIVO." || echo "❌ Kafka: no detectado."
curl -s "http://localhost:9200" > /dev/null && echo "✅ Elasticsearch: ACTIVO (puerto 9200)." || echo "❌ Elasticsearch: sin respuesta en 9200."
lsof -i:8888 -t > /dev/null 2>&1 && echo "✅ Jupyter Lab: ACTIVO (puerto 8888)." || echo "❌ Jupyter Lab: sin proceso en 8888."
echo "========================================================"
