# LAUNCHER-CONTAINER.md — Especificación del Launcher de Contenedor (macOS Apple Silicon)

> **Estado:** especificación. NO se construye aquí — la implementa el equipo del
> launcher (Wails), homóloga al panel de Vagrant. Este documento define el flujo,
> los comandos exactos (`podman` / `osascript`) y el contrato con el manifest de
> Hugging Face.

La 3ª vía del laboratorio **Quasar** (junto a Portable y Vagrant): correr el
stack como **contenedor Podman**. El alumno parte de una Mac **sin software** y
termina con el lab corriendo, **sin construir nada** (descarga la imagen
precompilada de HF) y sin Homebrew.

Imagen validada: `quasar-bigdata:1.0` (Debian 11, OpenJDK 17, Hadoop 3.3.6,
Kafka 4.0.0 KRaft, Elasticsearch 8.14.1, JupyterLab/PySpark), **arm64**, 3.62 GB.

---

## Principios

1. **Cero supuestos**: no asumir Homebrew ni Podman instalados.
2. **Elevación nativa solo donde se necesita** (instalar Podman): diálogo de
   administrador de macOS vía `osascript`.
3. **Logs claros en cada paso** + comando previsualizado antes de ejecutarlo.
4. **El alumno NO construye**: se baja la imagen de HF y se hace `podman load`.
5. **Canónico `podman run`** (NO `compose up` del `compose.yml` de dev, que trae
   `build:` y apunta a `:local` → intentaría compilar).
6. Dos capas en la UI, igual que Portable/Vagrant: **Preparación** y **Mi Laboratorio**.

---

## CAPA 1 — PREPARACIÓN

### 1.1 Diagnóstico
- `uname -s` / `uname -m` → confirmar **darwin / arm64** (Apple Silicon).
- RAM total y disco libre (avisar si RAM < 8 GB o disco < ~20 GB libres).
- ¿Existe el binario `podman`? → `command -v podman` o `/opt/podman/bin/podman`.
- ¿Hay una `podman machine`? → `podman machine list --format '{{.Name}} {{.Running}} {{.Memory}}'`.

### 1.2 Instalar Podman SIN Homebrew (instalador oficial .pkg)
La Mac nueva no tiene brew. Descargar el `.pkg` universal oficial e instalarlo
con elevación nativa:

```bash
# 1) Descargar el instalador oficial (con barra de progreso):
#    https://github.com/containers/podman/releases/download/vX.Y.Z/podman-installer-macos-universal.pkg
# 2) Instalar con privilegios de admin (sale el diálogo nativo de macOS):
osascript -e 'do shell script "installer -pkg \"/ruta/podman-installer-macos-universal.pkg\" -target /" with administrator privileges'
```
- (Atajo OPCIONAL: si `brew` ya existe → `brew install podman`. Pero el camino por
  defecto es el `.pkg`.)
- Tras instalar, `podman` queda en `/opt/podman/bin` → añadirlo al PATH del proceso.

### 1.3 Crear/arrancar la podman machine (memoria adaptada al host)
Dejar ~2.5–3 GB para macOS. Regla:

| RAM del host | `--memory` |
|---|---|
| 8 GB  | `5500`  |
| 16 GB | `12000` |
| 32 GB | `16000` |

```bash
podman machine init --cpus 4 --memory 5500 --disk-size 30   # ajustar --memory según tabla
podman machine start
podman machine ssh 'uname -m'      # debe decir aarch64
```
- La 1ª vez baja la imagen de la VM anfitriona (~600 MB–1 GB) — barra de progreso.
- Si ya existe una machine con poca RAM, detectarlo y **ofrecer recrearla**
  (`podman machine rm` + init con la memoria correcta).

> **Nota de almacenamiento (equipos con disco interno lleno):** la machine y la
> imagen viven bajo `XDG_DATA_HOME`. Si el disco interno está lleno, el launcher
> puede crear una imagen-disco **APFS sparse** en un volumen externo y exportar
> `XDG_DATA_HOME`/`XDG_CONFIG_HOME` a ese punto de montaje antes de `machine init`
> (exFAT no hospeda la VM directamente; APFS-sobre-exFAT sí). Validado en campo.

### 1.4 Descargar la imagen del lab desde Hugging Face (sin construir)
Leer el `manifest.txt` del dataset `abxda/bdp-lab`, clave **`darwin-arm64-container`**:

```
darwin-arm64-container.file=bdp-container-macos-arm64.tar.gz
darwin-arm64-container.sha256=<sha>
darwin-arm64-container.image=quasar-bigdata:1.0
darwin-arm64-container.size=~2.5 GB (imagen precompilada)
```

```bash
# Descargar <file> de https://huggingface.co/datasets/abxda/bdp-lab/resolve/main/<file>
#   (BARRA DE PROGRESO; ~2.5 GB)
# Verificar SHA-256 contra el manifest:
shasum -a 256 bdp-container-macos-arm64.tar.gz     # debe == darwin-arm64-container.sha256
# Cargar la imagen (restaura el tag quasar-bigdata:1.0):
gunzip -c bdp-container-macos-arm64.tar.gz | podman load
podman images quasar-bigdata        # confirmar quasar-bigdata:1.0
```
Elevación: **solo** en 1.2 (instalar Podman). Todo lo demás es sin admin.

---

## CAPA 2 — MI LABORATORIO

### 2.1 Arrancar el contenedor (canónico: `podman run`)
```bash
# Notebooks: usar una carpeta bajo $HOME (la podman machine monta $HOME en la VM;
# NO monta /Volumes). El launcher copia/usa los notebooks del alumno ahí.
mkdir -p "$HOME/quasar-work"

podman run -d --name quasar \
  -p 8888:8888 -p 9870:9870 -p 9000:9000 -p 9200:9200 -p 9092:9092 \
  -v "$HOME/quasar-work:/home/quasar/work:Z" \
  quasar-bigdata:1.0
```
- **`:Z`** en el `-v` es necesario (SELinux de la VM Fedora CoreOS) o las
  escrituras a `/home/quasar/work` fallan con *Permission denied*. (Validado.)
- Esperar a **"STACK INICIADO"** en `podman logs -f quasar` (~40–60 s).

> **Comodidad opcional** (en vez de `podman run`): un `compose-run.yml` **sin**
> `build:`, con `image: quasar-bigdata:1.0` y `pull_policy: never`. Pero el camino
> canónico de la spec es `podman run` (usa la imagen ya cargada, control explícito
> de puertos/volumen, consistente con `podman load` y con `.image` del manifest).

### 2.2 Estado de servicios
```bash
podman exec quasar quasar-check.sh
```
- ⚠️ **Nota validada:** `quasar-check.sh` reporta *"Jupyter ❌ sin proceso en
  8888"* como **falso negativo** — el endpoint responde 200 en `/lab`. El launcher
  debe verificar Jupyter por el **endpoint** (HTTP 8888 → 200), no por el check
  script. Para los demás (HDFS/Kafka/ES) el check es fiable.
- Endpoints para los badges de estado:
  - HDFS UI: `http://localhost:9870/dfshealth.html` → 200
  - Elasticsearch: `http://localhost:9200` → JSON
  - Jupyter: `http://localhost:8888/lab` → 200 (sin token)

### 2.3 Acciones
- **Abrir Jupyter**: `open http://localhost:8888/lab` (sin token; auth deshabilitada).
- **Explorador HDFS** (opcional): UI en `http://localhost:9870`.
- **Start/Stop**:
  - Start: `podman start quasar` (si ya existe) o el `podman run` de 2.1 (primera vez).
  - Stop: `podman stop quasar`.

### 2.4 Cierre limpio (al cerrar el launcher)
Como el panel de Vagrant apaga la VM, el launcher de contenedor debe **detener el
contenedor** al cerrarse:
```bash
podman stop quasar          # detiene el contenedor (datos HDFS/Kafka efímeros)
# (opcional) podman rm quasar   # si se quiere arranque siempre-limpio
```
- Detener el contenedor **no** apaga la podman machine (queda lista para la
  próxima sesión, arranque más rápido). Ofrecer "apagar también la máquina"
  (`podman machine stop`) como opción para liberar RAM del host.

---

## Contrato con el manifest (para el meta-launcher)
- Clave: **`darwin-arm64-container`**.
- `.file` → tar.gz a descargar; `.sha256` → verificación; `.image` →
  `quasar-bigdata:1.0` (el tag que restaura `podman load`); `.size` → informativo.
- El meta-launcher activa la opción **"Container"** para `darwin/arm64` cuando esta
  clave existe en el manifest.

---

## Multi-OS (futuro, incremental)
El mismo launcher sirve a los 3 SO cambiando solo:
1. **Instalador de Podman** por SO:
   - macOS → `.pkg` universal oficial (este doc).
   - Windows → instalador oficial / `winget install RedHat.Podman` (+ WSL2).
   - Linux → `apt`/`dnf`/`pacman` (sin VM: Podman corre nativo, no necesita machine).
2. **Imagen por arquitectura**: clave de manifest `--arch--container`
   (`darwin-arm64-container`, `windows-amd64-container`, `linux-amd64-container`).
   La imagen es multi-arch (el `Dockerfile` resuelve arm64/amd64 en build).
Enfocar **Apple Silicon** ahora; cargar el resto incremental.

---

## Resumen de comandos (referencia rápida)
```bash
# Preparación
osascript -e 'do shell script "installer -pkg \"...podman...pkg\" -target /" with administrator privileges'
podman machine init --cpus 4 --memory 5500 --disk-size 30 && podman machine start
gunzip -c bdp-container-macos-arm64.tar.gz | podman load
# Laboratorio
podman run -d --name quasar -p 8888:8888 -p 9870:9870 -p 9000:9000 -p 9200:9200 -p 9092:9092 \
  -v "$HOME/quasar-work:/home/quasar/work:Z" quasar-bigdata:1.0
podman logs -f quasar            # esperar "STACK INICIADO"
open http://localhost:8888/lab   # abrir Jupyter (sin token)
podman stop quasar               # cierre limpio
```
