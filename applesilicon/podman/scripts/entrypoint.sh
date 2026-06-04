#!/bin/bash
# entrypoint.sh — arranca el stack y mantiene el contenedor vivo (PID 1)
set -e

# Asegurar permisos del volumen de trabajo montado desde el host
mkdir -p /home/quasar/work
chown -R quasar:quasar /home/quasar/work 2>/dev/null || true

/usr/local/bin/quasar-start.sh

echo ""
echo "================================================================"
echo "  Quasar Big Data Lab (linux/$(uname -m)) LISTO"
echo "  JupyterLab : http://localhost:8888   (sin token)"
echo "  HDFS UI    : http://localhost:9870"
echo "  Elastic    : http://localhost:9200"
echo "  Kafka      : localhost:9092"
echo "  Estado     : podman exec quasar quasar-check.sh"
echo "================================================================"
echo ""

# Seguir el log de Jupyter y mantener vivo el contenedor.
touch /opt/bdpv5/logs/jupyter.log
exec tail -F /opt/bdpv5/logs/jupyter.log
