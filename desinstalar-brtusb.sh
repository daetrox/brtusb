#!/usr/bin/env bash
# Deshace la instalacion permanente de brtusb y devuelve el pincho a btusb.
# No recarga nada: se aplica al reiniciar (o al reconectar el pincho).

set -u
NAME=brtusb
VER=1.1

[ "$(id -u)" -eq 0 ] || { echo "ERROR: ejecuta con sudo"; exit 1; }

echo "== 1. Quitando DKMS =="
if command -v dkms >/dev/null 2>&1; then
	dkms remove -m "$NAME" -v "$VER" --all >/dev/null 2>&1 && echo "   ok" || echo "   (no estaba)"
else
	echo "   (dkms no instalado)"
fi

echo "== 2. Borrando copias del modulo =="
rm -rf "/usr/src/$NAME-$VER"
rm -f /lib/modules/*/updates/drivers/bluetooth/brtusb.ko
echo "   ok"

echo "== 3. Restaurando btusb =="
rm -f /etc/modprobe.d/brtusb.conf
rm -f /etc/modules-load.d/brtusb.conf
echo "   ok"

echo "== 4. Reconstruyendo dependencias =="
depmod -a
if command -v update-initramfs >/dev/null 2>&1; then
	update-initramfs -u >/dev/null 2>&1 && echo "   ok"
fi

echo
echo "== LISTO =="
echo "Reinicia. btusb volvera a intentarlo (y seguira sin funcionar con este pincho)."
