# Análisis de reconocimiento y migración — Proyecto Quasar → Apple Silicon

## 1. Qué es el proyecto

"Quasar" es una **Golden Image de laboratorio de Big Data** construida con
**Packer + Vagrant + VirtualBox** sobre **Debian 11 (x86_64)**. El producto final
es un archivo `.box` (~4.2 GB) que los estudiantes levantan con `vagrant up`.

Stack incluido (todo en una sola VM, instalado en `/opt/bdpv5`):

| Componente     | Versión           | Puerto(s)        |
|----------------|-------------------|------------------|
| OpenJDK        | 17                | —                |
| Hadoop (HDFS)  | 3.3.6             | 9000 RPC, 9870 UI|
| Kafka (KRaft)  | 4.0.0 (Scala 2.13)| 9092, 9093 ctrl  |
| Elasticsearch  | 8.14.1            | 9200             |
| Python venv    | 3.9 + JupyterLab, PySpark, hdfs, elasticsearch | 8888 |

Flujo de build en dos etapas: `debian-base-build/` (base Debian) →
`quasar-packer-build/` (instala el stack). Scripts de aprovisionamiento en
`quasar-packer-build/scripts/` (05-sysctl, 10-base, 20-quasar-stack, 30-vagrant,
40-cleanup). Scripts de control dentro de la VM: `quasar-start.sh`,
`quasar-stop.sh`, `quasar-check.sh`.

`GEMINI.md` (620 KB / ~7000 líneas) es la **transcripción completa de la sesión
del agente Gemini CLI** que construyó el proyecto: logs de Hadoop/Kafka/ES,
depuración y la bitácora de decisiones. Útil como historial, no es código.

## 2. Búsqueda de credenciales de HashiCorp Cloud / Vagrant Cloud

**Resultado: NO se encontraron contraseñas, tokens ni API keys de la nube de
HashiCorp (HCP) ni de Vagrant Cloud en el proyecto.**

Se buscaron patrones `hcp`, `hashicorp`, `vagrant cloud`, `atlas_token`,
`api_token`, `password`, `secret`, `token`, `bearer`, `Authorization` en
`GEMINI.md` y en todos los archivos. Lo único presente son:

- **Credenciales por defecto de Vagrant** (`vagrant`/`vagrant`): usuario y
  password del box, definidos en `preseed.cfg` y en `quasar.pkr.hcl`. Son las
  credenciales públicas y bien conocidas de cualquier box Vagrant — no son un
  secreto.
- **Llave pública oficial de Vagrant** descargada de GitHub
  (`hashicorp/vagrant/.../vagrant.pub`) — es pública por diseño.
- **Token de Jupyter vacío** (`--ServerApp.token=''`) — desactiva la auth de
  Jupyter para el laboratorio local. No es una credencial.
- Referencias a "Vagrant Cloud" en `GEMINI.md` (líneas ~6887-6943) son sólo
  **instrucciones de cómo dar de alta el box** (nombre sugerido
  `abxda/quasar-golden-image`, versión, descripción). **No contienen ningún
  token de subida.**

> Si en algún momento publicaste el box, el `VAGRANT_CLOUD_TOKEN` / token de HCP
> vive en tu `~/.vagrant.d/data/` o en variables de entorno de tu máquina, **no
> en este repositorio**. Nada que rotar desde aquí.

## 3. Qué se puede llevar a Apple Silicon y qué no

| Activo | ¿Reutilizable en Mac ARM? | Nota |
|--------|---------------------------|------|
| Archivos `.box` (4.2 GB) | ❌ No | Son imágenes **VirtualBox x86_64**. VirtualBox no corre en Apple Silicon y un box x86 no arranca nativo. **No los copies.** |
| Scripts de aprovisionamiento (`*.sh`) | ✅ Sí | Son shell puro, agnósticos de proveedor. Reusados en el `Dockerfile`. |
| `preseed.cfg`, `*.pkr.hcl` | ⚠️ Parcial | Específicos de Packer+VirtualBox+ISO x86. Sólo de referencia. |
| Configs (Hadoop/Kafka/ES) | ✅ Sí | `localhost`-based, idénticos. |
| Notebooks + `drone_sensors_data.csv` | ✅ Sí | Copiados a `applesilicon/notebooks/`. |
| Versiones del stack | ✅ Sí (con 1 ajuste) | **Elasticsearch debe bajarse en build `aarch64`**, no `x86_64`. Hadoop/Kafka son tarballs Java → sirven igual. |

### Detalles de arquitectura (lo importante)

- **Elasticsearch 8.14.1**: es específico de arquitectura. `install-stack.sh`
  detecta `dpkg --print-architecture` y baja `aarch64` (Mac ARM) o `x86_64`
  (Intel) automáticamente → imagen multi-arch.
- **Java (JAVA_HOME)**: no se fija a `arm64`; se usa un symlink estable
  `/usr/lib/jvm/java-17-current` que apunta a `java-17-openjdk-{arm64|amd64}`.
- **Hadoop 3.3.6**: el tarball es Java puro; sólo las *librerías nativas*
  (`libhadoop.so`) son x86. En arm64 verás el warning
  `Unable to load native-hadoop library` y usa el fallback Java. **Inofensivo**
  para el laboratorio.
- **Kafka 4.0.0 / PySpark / JupyterLab**: Java/Python puros → nativos en arm64.

## 4. Estrategia elegida: contenedor multi-arch con Podman

En lugar de portar VirtualBox (inviable en Apple Silicon), se reconstruye el
**mismo stack** como una **imagen de contenedor multi-arch (arm64 + amd64)**,
ejecutada con **Podman** (rootless, Apache 2.0; sin la restricción de licencia de
Docker Desktop). Los mismos archivos funcionan con Docker. Ventajas:

- Corre nativo en M1/M2/M3/M4 (sin emulación → rápido) y también en PCs Intel.
- **Una sola imagen para cohorte mixta**: cada alumno baja la variante de su
  arquitectura con el mismo comando.
- Mismo `/opt/bdpv5`, mismos puertos, mismos `quasar-start/stop/check`.
- Los notebooks existentes funcionan sin cambios (todo apunta a `localhost`).
- Reproducible y versionable, fiel a la filosofía IaC del proyecto original.

### Publicar la imagen ya compilada (equivalente a "subir el .box")

Sí es posible: se publica a un **registro de contenedores OCI** (GitHub
Container Registry / Docker Hub / Quay) con `podman manifest push`. Los
estudiantes hacen `podman compose pull` (sin compilar). Proceso completo en
`podman/PUBLICAR-IMAGEN.md`. El token del registro lo generas tú y vive en
`podman login` — **no se guarda en el repo** (coherente con la ausencia de
secretos del punto 2).

Ver `README.md` y `podman/PODMAN.md` para instrucciones, y
`alternativas/vm-alternativas.md` si prefieres una VM completa (Lima, VMware
Fusion o Parallels) en vez de un contenedor.
