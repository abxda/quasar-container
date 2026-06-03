# Quasar Big Data Lab — Apple Silicon (multi-arch, Podman)

Versión en **contenedor multi-arch** (Mac Apple Silicon arm64 **y** Windows/Linux
x86_64) del laboratorio Quasar, que sustituye la Golden Image `.box` de
VirtualBox (x86_64) por una imagen de contenedor con el mismo stack:
Hadoop 3.3.6 · Kafka 4.0.0 (KRaft) · Elasticsearch 8.14.1 · OpenJDK 17 ·
JupyterLab + PySpark.

Runtime recomendado: **Podman** (rootless, Apache 2.0, sin las restricciones de
licencia de Docker Desktop). Los mismos archivos funcionan con Docker.

> **Copia toda la carpeta `applesilicon/` a tu Mac.** Es autocontenida.
> **No copies los archivos `.box`** del proyecto original: son x86_64/VirtualBox
> y no funcionan en Apple Silicon (ver `ANALISIS-MIGRACION.md`).

## Contenido

```
applesilicon/
├── README.md                  # este archivo
├── ANALISIS-MIGRACION.md      # reconocimiento, hallazgo de credenciales, qué migra
├── PROMPT-CLAUDE-CODE.md      # prompt (Podman) listo para un agente Claude Code
├── podman/
│   ├── Dockerfile             # stack multi-arch (arm64 + amd64)
│   ├── compose.yml            # build local o usar imagen publicada
│   ├── PODMAN.md              # instalar Podman + machine + arranque + gotchas
│   ├── PUBLICAR-IMAGEN.md     # publicar la imagen ya compilada (registro OCI)
│   ├── .dockerignore
│   └── scripts/               # install-stack + quasar-start/stop/check + entrypoint
├── notebooks/                 # TestGlobalBigData.ipynb, kafka.ipynb, drone_sensors_data.csv
└── alternativas/
    └── vm-alternativas.md     # Lima / VMware Fusion / Parallels si quieres una VM
```

## Camino rápido (3 pasos)

1. **Instala Podman y crea la máquina con 8 GB** (crítico) — ver `podman/PODMAN.md`:
   ```bash
   brew install podman podman-compose
   podman machine init --cpus 4 --memory 8192 --disk-size 30 && podman machine start
   ```
2. **Construye y levanta**:
   ```bash
   cd applesilicon/podman
   podman compose build && podman compose up -d
   podman compose logs -f          # espera "STACK INICIADO"
   ```
3. **Abre** http://localhost:8888 (JupyterLab, sin token).

| Servicio        | URL / endpoint            |
|-----------------|---------------------------|
| JupyterLab      | http://localhost:8888  (sin token) |
| HDFS NameNode UI| http://localhost:9870     |
| Elasticsearch   | http://localhost:9200     |
| Kafka broker    | localhost:9092            |
| HDFS RPC        | hdfs://localhost:9000     |

Tus notebooks viven en `applesilicon/notebooks/` (montados en
`/home/quasar/work`) — edítalos desde el Mac o desde Jupyter.

## Para una cohorte (sin que compilen)

Publica la imagen **multi-arch** una vez y los estudiantes solo hacen `pull`
(misma orden para Macs ARM y PCs Intel — cada uno baja su variante). Proceso
completo en **`podman/PUBLICAR-IMAGEN.md`**.

## Comandos útiles

```bash
podman exec -it quasar quasar-check.sh   # estado de los servicios
podman exec -it quasar quasar-stop.sh    # detener servicios
podman exec -it quasar quasar-start.sh   # arrancar de nuevo
podman exec -it quasar bash              # shell dentro del lab
podman compose down                      # apagar y eliminar el contenedor
```

## Notas de compatibilidad

- **Multi-arch**: el `Dockerfile` no fija la arquitectura (Java vía symlink
  `java-17-current`; Elasticsearch elegido por `dpkg --print-architecture`).
- **Hadoop** muestra `Unable to load native-hadoop library` en arm64: esperado
  (usa fallback Java). El laboratorio funciona igual.
- **Podman rootless**: sin `memlock` ilimitado; ES con `bootstrap.memory_lock:
  false` y `discovery.type: single-node`. Si Jupyter no escribe en el volumen,
  es SELinux → usa el sufijo `:Z`/`:U` (ver `compose.yml`).
- Los notebooks no requieren cambios: todo apunta a `localhost`.
- Datos HDFS/Kafka **efímeros** por defecto; persístelos con el volumen
  `quasar-data` (comentado en `compose.yml`).

¿Prefieres una VM completa en lugar de un contenedor? Ver
`alternativas/vm-alternativas.md`.
