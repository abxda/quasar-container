# quasar-container

**3ª vía** del laboratorio **Quasar Big Data** (junto a *Portable* y *Vagrant*):
correr el stack como **contenedor Podman** — nativo en macOS Apple Silicon (arm64)
y multi-arch (arm64 + amd64).

Stack: Debian 11 · OpenJDK 17 · Hadoop 3.3.6 · Kafka 4.0.0 (KRaft) ·
Elasticsearch 8.14.1 · JupyterLab + PySpark.

## Contenido

| Ruta | Qué es |
|---|---|
| [`LAUNCHER-CONTAINER.md`](LAUNCHER-CONTAINER.md) | Especificación del launcher de contenedor (Wails) — flujo, comandos `podman`/`osascript`, contrato con el manifest de HF. |
| `applesilicon/podman/` | `Dockerfile` multi-arch, `compose.yml`, `scripts/` (`install-stack.sh`, `quasar-start/stop/check.sh`, `entrypoint.sh`). |
| `applesilicon/notebooks/` | Notebooks de prueba (`TestGlobalBigData.ipynb`, `kafka.ipynb`) + dataset. |
| `applesilicon/*.md` | README, análisis de migración, alternativas. |

## Imagen precompilada (Hugging Face)

La imagen **NO se construye** en la máquina del alumno: se descarga precompilada
del dataset `abxda/bdp-lab` (clave de manifest `darwin-arm64-container`) y se carga
con `podman load`. El launcher orquesta descarga → verificación SHA-256 → load → run.

```bash
# El alumno (resumido):
gunzip -c bdp-container-macos-arm64.tar.gz | podman load     # restaura quasar-bigdata:1.0
podman run -d --name quasar \
  -p 8888:8888 -p 9870:9870 -p 9000:9000 -p 9200:9200 -p 9092:9092 \
  -v "$HOME/quasar-work:/home/quasar/work:Z" quasar-bigdata:1.0
open http://localhost:8888/lab
```

## Construir la imagen (solo desarrollo / mantenimiento)

```bash
cd applesilicon/podman
podman compose build           # quasar-bigdata:local (~10-15 min; arm64 o amd64 según host)
```

Validado en macOS Apple Silicon (M2, 8 GB): el stack completo arranca y los 4
servicios (HDFS/Kafka/ES/Jupyter) responden. Ver `LAUNCHER-CONTAINER.md` para el
detalle de validación y notas (p. ej. `quasar-check.sh` da falso negativo en
Jupyter — validar por endpoint).
