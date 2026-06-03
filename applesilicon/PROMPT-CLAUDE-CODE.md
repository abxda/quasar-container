# Prompt para Claude Code corriendo en el Mac (Apple Silicon) — Podman

Copia el bloque de abajo y pégalo como primer mensaje a **Claude Code** abierto
dentro de la carpeta `applesilicon/` ya copiada a tu Mac. Está pensado para que
el agente levante, valide y, si hace falta, repare y/o publique el laboratorio
Quasar usando **Podman**.

---

```text
Eres un agente Claude Code trabajando en un Mac con Apple Silicon (arm64).
Estás dentro de la carpeta `applesilicon/`, que contiene la versión en
contenedor (multi-arch) del laboratorio de Big Data "Quasar" (originalmente una
Golden Image Packer/Vagrant/VirtualBox para Debian 11 x86_64). El runtime es
PODMAN (rootless, Apache 2.0), no Docker. El objetivo es tener el laboratorio
corriendo de forma NATIVA en este Mac.

CONTEXTO DEL STACK (todo en un solo contenedor, instalado en /opt/bdpv5):
- OpenJDK 17 (JAVA_HOME = symlink /usr/lib/jvm/java-17-current, multi-arch)
- Hadoop 3.3.6        -> HDFS RPC 9000, NameNode UI 9870
- Kafka 4.0.0 (KRaft) -> 9092
- Elasticsearch 8.14.1 (build elegido por arquitectura) -> 9200
- Python venv + JupyterLab + PySpark + hdfs + elasticsearch -> 8888
Carpeta de trabajo: applesilicon/podman/ (Dockerfile, compose.yml, scripts/).
Scripts de control dentro del contenedor: quasar-start.sh / quasar-stop.sh /
quasar-check.sh. Los notebooks del host (applesilicon/notebooks/) se montan en
/home/quasar/work.

PARTICULARIDADES (NO son errores):
- Imagen MULTI-ARCH: install-stack.sh detecta la arquitectura y baja el
  Elasticsearch correcto (aarch64 en este Mac). NO fijes la arquitectura.
- Hadoop muestra "Unable to load native-hadoop library" en arm64 y usa fallback
  Java. Es esperado e inofensivo.
- Elasticsearch corre como usuario no-root 'quasar', con discovery.type
  single-node (bootstrap checks = warnings) y bootstrap.memory_lock: false.
- Podman rootless: NO uses memlock ilimitado. Si Jupyter no escribe en
  /home/quasar/work, es SELinux: añade el sufijo :Z (o :U) al volumen en
  compose.yml (documentado ahí).

TU TAREA:
1. Verifica el entorno: `podman version`, `uname -m` (arm64), y que exista una
   `podman machine` con >= 8 GB de RAM (`podman machine inspect | grep -i memory`).
   Si no hay Podman: `brew install podman podman-compose`. Si la máquina no
   existe o tiene poca RAM: `podman machine init --cpus 4 --memory 8192
   --disk-size 30 && podman machine start`. Confirma `podman machine ssh 'uname -m'`
   == aarch64.
2. Construye: `cd podman && podman compose build`. Si una descarga falla
   (Hadoop/Kafka en archive.apache.org, ES en artifacts.elastic.co), reintenta o
   sugiere mirror; NO cambies versiones sin avisarme.
3. Levanta: `podman compose up -d` y sigue `podman compose logs -f` hasta ver
   "STACK INICIADO".
4. Valida: `podman exec quasar quasar-check.sh` -> HDFS, Kafka, Elasticsearch y
   Jupyter ACTIVOS. Además:
   - `curl -s localhost:9200` devuelve JSON de Elasticsearch.
   - `curl -s -o /dev/null -w "%{http_code}" localhost:9870` devuelve 200.
   - JupyterLab responde en http://localhost:8888 sin pedir token.
5. Prueba de humo de los notebooks en notebooks/ (TestGlobalBigData.ipynb y
   kafka.ipynb): PySpark arranca, HDFS acepta escritura/lectura, el cliente
   elasticsearch conecta. Si algo falla, diagnostícalo y propón el fix mínimo.

(OPCIONAL — solo si te lo pido) PUBLICAR la imagen para la cohorte mixta:
   Sigue podman/PUBLICAR-IMAGEN.md. Construye multi-arch
   (`podman build --platform linux/arm64,linux/amd64 --manifest ...`) y publica
   con `podman manifest push` al registro que te indique. NUNCA escribas el token
   del registro en archivos; usa `podman login` con el token por STDIN.

REGLAS:
- No modifiques versiones del stack salvo que te lo pida; si una es irrecuperable,
  explícame el problema y las opciones antes de cambiar.
- Trabaja incremental y muéstrame los comandos y su salida real.
- Si HDFS/Kafka necesitan reformateo (p. ej. tras montar un volumen vacío),
  avísame antes de borrar datos.
- Al terminar, dame un resumen del estado y los enlaces (8888/9870/9200/9092).

Empieza por el paso 1.
```

---

## Sugerencia opcional: archivo `CLAUDE.md`

Si quieres que el contexto persista entre sesiones, crea en la raíz de
`applesilicon/` un `CLAUDE.md` con un resumen del stack, los puertos y las
particularidades de arriba. Así el agente lo carga automáticamente.
