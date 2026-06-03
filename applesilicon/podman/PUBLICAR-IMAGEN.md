# Publicar la imagen Quasar ya compilada (registro de contenedores)

**Sí, se puede publicar la imagen ya construida** para que los estudiantes
**no tengan que compilar** (se ahorran los ~10-15 min de build y las descargas
de Hadoop/Kafka/ES). Solo hacen `podman pull` y `podman compose up -d`.

Esto es el equivalente moderno de "subir el `.box` a Vagrant Cloud", pero a un
**registro de contenedores OCI**. Y como la imagen es **multi-arch**, una sola
publicación sirve a tu cohorte mixta: Macs Apple Silicon (arm64) y PCs
Windows/Linux Intel (amd64).

> Recuerda (ver `../ANALISIS-MIGRACION.md`): el proyecto **no contiene tokens de
> HashiCorp/Vagrant Cloud**. El token del registro que uses aquí (GitHub, Docker
> Hub, Quay) lo generas tú y vive en tu sesión / `podman login`, **nunca lo
> escribas en estos archivos ni en el `compose.yml`**.

---

## 1. Elegir registro

| Registro | Imagen privada gratis | Recomendado para |
|----------|------------------------|------------------|
| **GitHub Container Registry** (`ghcr.io`) | Sí (ilimitadas) | Educación / un solo curso. **Recomendado.** |
| **Quay.io** | Sí | Alternativa open-source friendly |
| **Docker Hub** (`docker.io`) | 1 privada / públicas ilimitadas | Difusión pública |

Los ejemplos usan `ghcr.io/abxda/quasar-bigdata`. Cambia `abxda` por tu usuario
y elige una etiqueta de versión (alineada al proyecto: `1.0`, `1.0.10`, etc.).

## 2. Autenticarte en el registro (una sola vez)

GitHub Container Registry necesita un **Personal Access Token (classic)** con el
scope `write:packages`. Créalo en GitHub → Settings → Developer settings →
Tokens. Luego:

```bash
# El token se pasa por STDIN para que no quede en el historial del shell.
echo "$GHCR_TOKEN" | podman login ghcr.io -u abxda --password-stdin
```

(Para Docker Hub: `podman login docker.io`; para Quay: `podman login quay.io`.)

## 3A. Publicar MULTI-ARCH (recomendado — cohorte mixta) con `podman manifest`

Una imagen multi-arch es un **manifest list** que agrupa la variante arm64 y la
amd64 bajo un mismo nombre. Podman construye ambas y empaqueta el manifest:

```bash
cd podman/

# 1) Crear el manifest (lista vacía)
podman manifest create quasar-bigdata:1.0

# 2) Construir AMBAS arquitecturas y añadirlas al manifest.
#    En un Mac Apple Silicon, amd64 se construye por emulación (qemu, más lento
#    pero funciona). En la podman machine la emulación viene incluida.
podman build --platform linux/arm64,linux/amd64 \
  --manifest quasar-bigdata:1.0 \
  -f Dockerfile .

# 3) Publicar el manifest + ambas imágenes al registro
podman manifest push --all \
  quasar-bigdata:1.0 \
  docker://ghcr.io/abxda/quasar-bigdata:1.0
```

> Si la build amd64 emulada es muy lenta, alternativa: construye cada arch en una
> máquina nativa de esa arquitectura (un Mac para arm64, un PC/CI Linux x86 para
> amd64), publica cada una con su sufijo y únelas con `podman manifest add` +
> `podman manifest push`. Para un curso, la build emulada de un solo paso suele
> bastar.

## 3B. Publicar UNA sola arquitectura (rápido, si tu cohorte es homogénea)

```bash
cd podman/
podman build -t ghcr.io/abxda/quasar-bigdata:1.0 -f Dockerfile .   # tu arch actual
podman push ghcr.io/abxda/quasar-bigdata:1.0
```

## 4. Hacer la imagen pública (para que los alumnos la bajen sin login)

En `ghcr.io`: ve a tu perfil → Packages → `quasar-bigdata` → Package settings →
Change visibility → **Public**. (Docker Hub/Quay tienen un toggle equivalente.)
Si la dejas privada, cada alumno deberá `podman login` con un token de lectura
(`read:packages`).

## 5. Uso del lado del estudiante (SIN compilar)

El alumno solo necesita la carpeta `applesilicon/` (notebooks + `compose.yml`),
Podman y la `podman machine` con 8 GB (ver `PODMAN.md` pasos 1-2). Edita
`compose.yml`: comenta el bloque `build:` y descomenta/ajusta la línea `image:`:

```yaml
services:
  quasar:
    # build:                       # <- comentado
    #   context: .
    #   dockerfile: Dockerfile
    image: ghcr.io/abxda/quasar-bigdata:1.0   # <- descomentado
    ...
```

Luego:

```bash
cd applesilicon/podman
podman compose pull      # baja la variante de SU arquitectura automáticamente
podman compose up -d
podman compose logs -f   # espera "STACK INICIADO"
open http://localhost:8888
```

Podman/Docker seleccionan **solo** la variante (arm64 o amd64) que corresponde a
la máquina del alumno: el Mac baja arm64, el PC Intel baja amd64. Mismo comando
para todos.

## 6. Verificar el manifest multi-arch publicado

```bash
podman manifest inspect ghcr.io/abxda/quasar-bigdata:1.0 | grep -A2 architecture
# Debe listar "arm64" y "amd64".
```

---

## Notas

- **Tamaño**: la imagen Quasar comprimida ronda 2-3 GB por arquitectura. Los
  registros gratuitos lo soportan; la primera descarga del alumno tardará según
  su red, pero es una sola vez (queda cacheada).
- **Datos efímeros**: la imagen publicada trae HDFS/Kafka ya formateados; los
  datos generados por el alumno son efímeros salvo que active el volumen
  `quasar-data` (ver `compose.yml`).
- **Versionado**: etiqueta cada release (`:1.0`, `:1.1`, …) y deja `:latest`
  apuntando a la estable. Así controlas qué versión usa la cohorte, igual que
  hacías con `box_version` en Packer.
