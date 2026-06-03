# Quasar Big Data Lab — arranque con Podman (Apple Silicon)

Versión Podman del laboratorio. **El `Dockerfile` no cambia**: Podman lo
construye igual que Docker. Solo cambia el runtime (de Docker Desktop a
`podman machine`) y se ajusta el `compose.yml` para rootless (ver `compose.yml`).

Licencia del runtime: **Podman / Podman Desktop son Apache 2.0** — libres para
uso comercial/corporativo, sin la trampa de Docker Desktop (que cobra arriba de
250 empleados o $10M de ingresos).

---

## 1. Instalar Podman en el Mac

Opción CLI (mínima):

```bash
brew install podman podman-compose
```

Opción con GUI (recomendada para repartir a estudiantes): instala también
**Podman Desktop** (`brew install --cask podman-desktop`), que da la misma
comodidad visual que Docker Desktop pero open source.

## 2. Crear la máquina Podman con RAM suficiente (CRÍTICO)

La `podman machine` arranca con **2 GB por defecto**, y eso mata el stack por
OOM (ES + Hadoop + 2 JVMs + Jupyter). Dale 8 GB:

```bash
podman machine init --cpus 4 --memory 8192 --disk-size 30
podman machine start
podman machine ssh 'uname -m'   # debe decir aarch64
```

Si ya tenías una máquina con poca RAM:

```bash
podman machine stop && podman machine rm
podman machine init --cpus 4 --memory 8192 --disk-size 30 && podman machine start
```

## 3. Construir y levantar

```bash
cd podman/            # carpeta con Dockerfile, compose.yml y scripts/
podman compose build  # ~10-15 min la primera vez (descarga Hadoop/Kafka/ES)
podman compose up -d
podman compose logs -f   # espera "STACK INICIADO"
```

> `podman compose` (con espacio) delega en `podman-compose`. Si por alguna razón
> no lo encuentra, usa directamente `podman-compose build` / `podman-compose up -d`.

## 4. Validar

```bash
podman exec quasar quasar-check.sh                    # HDFS/Kafka/ES/Jupyter ACTIVOS
curl -s localhost:9200 | head                          # JSON de Elasticsearch
curl -s -o /dev/null -w "%{http_code}\n" localhost:9870   # 200 = HDFS UI
open http://localhost:8888                              # JupyterLab (sin token)
```

| Servicio         | URL / endpoint            |
|------------------|---------------------------|
| JupyterLab       | http://localhost:8888  (sin token) |
| HDFS NameNode UI | http://localhost:9870     |
| Elasticsearch    | http://localhost:9200     |
| Kafka broker     | localhost:9092            |
| HDFS RPC         | hdfs://localhost:9000     |

---

## Mapa de comandos Docker -> Podman

| Docker                         | Podman                          |
|--------------------------------|---------------------------------|
| `docker compose build`         | `podman compose build`          |
| `docker compose up -d`         | `podman compose up -d`          |
| `docker compose logs -f`       | `podman compose logs -f`        |
| `docker compose down`          | `podman compose down`           |
| `docker exec -it quasar bash`  | `podman exec -it quasar bash`   |
| `docker ps`                    | `podman ps`                     |

El resto (`quasar-start.sh`, `quasar-stop.sh`, `quasar-check.sh`) corre dentro
del contenedor exactamente igual: `podman exec -it quasar quasar-check.sh`.

---

## Gotchas específicos de Podman rootless (los que muerden con este stack)

1. **RAM de la máquina.** El #1. Sin los 8 GB del paso 2, ES o Hadoop mueren
   silenciosamente. Si algo no arranca, primero `podman machine inspect | grep -i memory`.
2. **memlock.** Ya resuelto en `compose.yml` (se quitó `memlock: -1`). No lo
   reactives en rootless.
3. **`vm.max_map_count` para Elasticsearch.** Es un sysctl del kernel de la VM,
   no del Mac. Con `discovery.type=single-node` ES degrada el bootstrap check a
   warning y arranca igual. Si en otro contexto lo necesitas, se ajusta dentro de
   la podman machine: `podman machine ssh 'sudo sysctl -w vm.max_map_count=262144'`.
4. **Permisos del bind mount de notebooks.** Si Jupyter no puede escribir en
   `/home/quasar/work`, aplica el sufijo `:Z` o `:U` documentado en `compose.yml`.

---

## (Opcional) Capa Dev Containers encima de Podman

Si quieres que los estudiantes abran el lab con "Reopen in Container" desde VS
Code sobre Podman, agrega un `.devcontainer/devcontainer.json`:

```json
{
  "name": "Quasar Big Data Lab",
  "dockerComposeFile": "../compose.yml",
  "service": "quasar",
  "workspaceFolder": "/home/quasar/work",
  "forwardPorts": [8888, 9870, 9200, 9092],
  "overrideCommand": false
}
```

Y apunta VS Code a Podman en `settings.json`:

```json
{ "dev.containers.dockerPath": "podman" }
```

`overrideCommand: false` es importante: deja que corra tu `entrypoint.sh`
(que lanza quasar-start) en vez de reemplazarlo. Para un lab donde el trabajo
real ocurre en Jupyter en el navegador, esta capa es opcional — `podman compose
up -d` + abrir `:8888` ya basta.

---

## Multi-arch (cohorte mixta) — YA IMPLEMENTADO

La imagen **ya es multi-arch**: el `Dockerfile` no fija la arquitectura. Resuelve
Java con un symlink estable `/usr/lib/jvm/java-17-current` (apuntando a
`java-17-openjdk-$(dpkg --print-architecture)`) y `install-stack.sh` detecta la
arquitectura para bajar el Elasticsearch correcto (`aarch64` o `x86_64`). Por eso
el `compose.yml` ya **no** lleva `platform: linux/arm64`: Podman/Docker eligen la
arquitectura del host (arm64 en Mac Apple Silicon, amd64 en Windows/Linux Intel).

- **Construir localmente**: `podman compose build` produce la imagen para TU
  máquina, sea ARM o x86.
- **Publicar una imagen multi-arch única** (un solo nombre que sirve a toda la
  cohorte, Macs y PCs): ver **`PUBLICAR-IMAGEN.md`** — usa
  `podman build --platform linux/arm64,linux/amd64 --manifest` + `podman manifest
  push`. Los estudiantes solo hacen `podman compose pull` y baja automáticamente
  la variante de su arquitectura.

## Publicar la imagen ya compilada

Para que los estudiantes **no compilen** (se ahorran build + descargas), publica
la imagen a un registro (GitHub Container Registry / Docker Hub / Quay) y que la
descarguen con `podman pull`. Proceso completo en **`PUBLICAR-IMAGEN.md`**.
