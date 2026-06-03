# Alternativas: VM completa en Apple Silicon (en vez de Docker)

La ruta recomendada es **Docker** (`../docker/`). Si necesitas una VM Linux
completa (por ejemplo para reproducir el entorno Vagrant tal cual, o para usar
`systemd`), estas son las opciones que SÍ funcionan en Apple Silicon. Todas
requieren una **box/imagen `arm64`** — un box x86 no sirve.

## Opción A — Lima (lima-vm) [ligera, recomendada para VM]

`brew install lima`. Lima levanta VMs Linux arm64 con `virtualization.framework`
de Apple. Crea un `quasar.yaml`:

```yaml
arch: aarch64
images:
  - location: "https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-arm64.qcow2"
provision:
  - mode: system
    script: |
      #!/bin/bash
      # Pega aquí el contenido adaptado de install-stack.sh (usa el usuario por
      # defecto de Lima en vez de 'quasar').
 portForwards:
  - { guestPort: 8888, hostPort: 8888 }
  - { guestPort: 9870, hostPort: 9870 }
  - { guestPort: 9200, hostPort: 9200 }
  - { guestPort: 9092, hostPort: 9092 }
```
`limactl start quasar.yaml` → `limactl shell quasar` → `quasar-start.sh`.

## Opción B — Vagrant + VMware Fusion (gratis desde 2024)

1. Instala VMware Fusion (gratuito para uso personal) y el plugin
   `vagrant plugin install vagrant-vmware-desktop`.
2. Usa un box **arm64** (p. ej. `bento/debian-12` tiene variante arm64, o
   `gyptazy/debian12-arm64`).
3. Reaprovecha los scripts `quasar-packer-build/scripts/*` como
   `config.vm.provision "shell"`, cambiando la descarga de Elasticsearch a
   `aarch64` (o reutiliza `../podman/scripts/install-stack.sh`, que ya detecta la
   arquitectura automáticamente).

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "bento/debian-12"   # asegúrate de la variante arm64
  config.vm.network "forwarded_port", guest: 8888, host: 8888
  config.vm.network "forwarded_port", guest: 9870, host: 9870
  config.vm.network "forwarded_port", guest: 9200, host: 9200
  config.vm.network "forwarded_port", guest: 9092, host: 9092
  config.vm.provision "shell", path: "scripts/install-stack.sh"
  config.vm.provider "vmware_desktop" do |v|
    v.memory = 6144
    v.cpus = 4
  end
end
```

## Opción C — Parallels Desktop (de pago) + Vagrant

`vagrant plugin install vagrant-parallels`, box arm64 (`bento/debian-12` con
provider parallels). Mismo aprovisionamiento que arriba.

## ¿Y reconstruir un `.box` con Packer?

Posible pero más laborioso: Packer con el plugin **qemu** o **vmware-iso**
apuntando a un ISO **arm64** de Debian, reusando `preseed.cfg` y los scripts.
Sólo vale la pena si necesitas redistribuir un `.box` arm64 a muchos alumnos.
Para uso individual, Docker o Lima son mucho más rápidos.

## Regla de oro para cualquier opción

- Imagen base **arm64** (nunca x86).
- **Elasticsearch** → build `linux-aarch64`.
- Hadoop/Kafka/PySpark → tarballs Java, sin cambios (ignora el warning de
  librería nativa de Hadoop).
