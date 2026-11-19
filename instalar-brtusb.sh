#!/usr/bin/env bash
# Instala el driver brtusb de forma permanente.
#   - con DKMS si se puede (se reconstruye solo al actualizar el kernel)
#   - si no, copia el modulo ya compilado
#   - impide que btusb se quede con el pincho (lo deja inservible)
# No recarga el driver: el cambio se aplica al reiniciar.

set -u
NAME=brtusb
VER=1.1
SRC="$(cd "$(dirname "$0")" && pwd)"
KREL=$(uname -r)

[ "$(id -u)" -eq 0 ] || { echo "ERROR: ejecuta con sudo"; exit 1; }
[ -f "$SRC/brtusb.c" ] || { echo "ERROR: falta $SRC/brtusb.c"; exit 1; }

echo "== 1. Comprobando que el modulo es para este kernel =="
if ! modinfo "$SRC/brtusb.ko" 2>/dev/null | grep -q "vermagic:.*$KREL"; then
	echo "ERROR: el modulo no es para $KREL"
	exit 1
fi
echo "   ok ($KREL)"

echo "== 2. Instalando por DKMS =="
USE_DKMS=1
if ! command -v dkms >/dev/null 2>&1; then
	echo "   dkms no esta instalado, intentando instalarlo..."
	apt-get update -qq >/dev/null 2>&1 || true
	apt-get install -y dkms >/dev/null 2>&1 || USE_DKMS=0
fi

if [ "$USE_DKMS" -eq 1 ] && command -v dkms >/dev/null 2>&1; then
	rm -rf "/usr/src/$NAME-$VER"
	mkdir -p "/usr/src/$NAME-$VER"
	cp "$SRC/brtusb.c" "$SRC/Makefile" "$SRC/dkms.conf" "/usr/src/$NAME-$VER/"
	dkms remove -m "$NAME" -v "$VER" --all >/dev/null 2>&1 || true
	if dkms add -m "$NAME" -v "$VER" >/dev/null 2>&1 &&
	   dkms build -m "$NAME" -v "$VER" >/dev/null 2>&1 &&
	   dkms install -m "$NAME" -v "$VER" --force >/dev/null 2>&1; then
		echo "   ok (DKMS: se reconstruira solo con cada kernel nuevo)"
	else
		echo "   DKMS fallo, se usara la copia simple"
		USE_DKMS=0
	fi
else
	USE_DKMS=0
fi

if [ "$USE_DKMS" -eq 0 ]; then
	install -D -m 644 "$SRC/brtusb.ko" \
		"/lib/modules/$KREL/updates/drivers/bluetooth/brtusb.ko" || exit 1
	depmod -a
	echo "   ok (copia simple; habra que repetir tras cada kernel nuevo)"
fi

echo "== 3. Impedir que btusb se quede con el pincho =="
cat > /etc/modprobe.d/brtusb.conf <<'EOF'
# El pincho BARROT 33fa:0001 solo funciona con el driver brtusb.
# btusb tambien lo acepta (coincide por clase USB) y lo deja sin responder,
# asi que se bloquea su carga automatica. Otros adaptadores Bluetooth USB
# dejarian de funcionar; para volver atras:
#   sudo bash /home/daetrox/brtusb/desinstalar-brtusb.sh
blacklist btusb
options brtusb debug_packets=0
EOF

echo "$NAME" > /etc/modules-load.d/brtusb.conf
echo "   ok"

echo "== 4. Actualizando initramfs y dependencias =="
depmod -a
if command -v update-initramfs >/dev/null 2>&1; then
	update-initramfs -u >/dev/null 2>&1 && echo "   ok" || echo "   aviso: initramfs no actualizado"
else
	echo "   (sin update-initramfs en este sistema)"
fi

echo
echo "== LISTO =="
echo "Reinicia el equipo. Al arrancar, el pincho debe aparecer ya listo:"
echo "   bluetoothctl show"
echo
echo "Para volver al driver normal: sudo bash /tmp/opencode/desinstalar-brtusb.sh"
