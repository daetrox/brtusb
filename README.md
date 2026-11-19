# brtusb — driver Linux para el pincho Bluetooth BARROT 33fa:0001

Driver HCI sobre USB para el adaptador **BARROT «USB2.0-BT»** (`33fa:0001`,
familia **BR8554**, `bcdDevice 88.91`), portado del driver de Windows
«BARROT BRLink» (`brtlinkusb_54.sys`).

El `btusb` de Linux acepta el pincho por su clase USB (`E0/01/01`) pero no
consigue inicializarlo:

```
Bluetooth: hci0: Opcode 0x0c03 failed: -110
```

`-110` es *timeout*: el adaptador no contesta al `Reset`, así que el controlador
queda inservible (`Powered: no`, conexiones que fallan con
`br-connection-timeout`). Con este driver arranca, se enciende y mantiene
conexiones estables.

Probado en PikaOS 4 con kernel `7.3.3-pikaos` y un Redmi Note 12S: más de 40 s
conectado y más de 4000 paquetes ACL sin errores.

## Requisitos

- Linux con Bluetooth (`CONFIG_BT`).
- `dkms` y los headers del kernel en uso:

```bash
sudo apt install dkms linux-headers-$(uname -r)
```

- Para compilar a mano hace falta **clang/LLVM**: el kernel de PikaOS se compila
  con clang y sus flags rompen gcc.

## Instalación

### Paquete .deb (recomendado)

```bash
bash packaging/build-deb.sh
sudo apt install ./dist/brtusb-dkms_1.1-1_all.deb
```

El paquete:

- Deja la fuente en `/usr/src/brtusb-1.1/` y la registra en DKMS, que la
  recompila sola con cada kernel nuevo.
- Instala `/etc/modprobe.d/brtusb.conf` con `blacklist btusb` (si no, `btusb` se
  queda con el pincho y lo deja sin responder).
- Instala `/etc/modules-load.d/brtusb.conf` para cargar el driver al arrancar.

### Script

```bash
sudo bash instalar-brtusb.sh
```

Hace lo mismo pero sin paquete: intenta DKMS y, si no puede, copia el módulo ya
compilado (en ese caso hay que repetirlo tras cada kernel nuevo).

### Compilar a mano

```bash
make LLVM=1 -C /lib/modules/$(uname -r)/build M=$PWD modules
sudo insmod brtusb.ko        # prueba rapida; no instala nada
```

## Comprobar

```bash
sudo bash verificar-brtusb.sh
```

Debe mostrar `brtusb: SI`, `btusb: no`, `Powered: yes` y `Connected: yes`
durante la vigilancia.

## Desinstalar

```bash
sudo apt remove brtusb-dkms     # si se instalo el .deb
sudo bash desinstalar-brtusb.sh # si se instalo con el script
```

`btusb` volverá a intentarlo y, con este pincho, seguirá sin funcionar.

## Avisos

- **No recargar el driver con `rmmod`/`insmod`**: el pincho puede quedar sin
  enumerar a nivel USB (`unable to enumerate USB device`). Solución:
  desenchufar, esperar 5 s y volver a enchufar; mejor reiniciar.
- **Otros adaptadores Bluetooth USB** dejan de funcionar mientras `btusb` esté
  bloqueado. Es el precio de que este pincho funcione.
- SCO (audio de llamadas) no está probado.
- `usbmon` no existe en este kernel; el diagnóstico se hace con el parámetro
  `debug_packets=1`, que vuelca los paquetes ACL al log del kernel.

## Estructura

| Fichero | Para qué |
|---|---|
| `brtusb.c` | Driver completo (transporte HCI USB, RX/TX, SCO). |
| `dkms.conf`, `Makefile` | Compilación fuera del árbol y DKMS. |
| `instalar-brtusb.sh` | Instalación sin paquete. |
| `desinstalar-brtusb.sh` | Vuelta a `btusb`. |
| `verificar-brtusb.sh` | Comprobación tras reiniciar. |
| `packaging/` | Paquete `.deb` (`build-deb.sh` + metadatos). |

## Cómo funciona

El driver de Windows es un transporte HCI USB puro (H:2) al estilo del viejo
ejemplo CSR `csrbc01`: comandos por EP0 como petición de clase
(`bmRequestType 0x21`, `bRequest 0x00`), eventos por el endpoint de
interrupción, ACL por bulk y SCO por isochronous con cambio de *alternate
setting*. Toda la lógica de perfiles y los parches de firmware los aplica
`btmgr.exe` desde espacio de usuario con comandos HCI del fabricante; el driver
del kernel no descarga firmware. En Linux, BlueZ ocupa ese lugar.

El puerto reproduce además los enganches del fabricante: el comando mágico
`EE EE 01 02 03 04 05` no se envía al dispositivo y el cambio a modo HID se
hace con una transferencia de control de proveedor en EP0.

## Licencia

GPL-2.0. Ver `LICENSE`.
