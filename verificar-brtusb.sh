#!/usr/bin/env bash
# Comprueba, tras reiniciar, que el pincho arranca con el driver brtusb
# y que la conexion con el movil aguanta.
#   sudo bash ~/brtusb/verificar-brtusb.sh

set -u
MAC=14:99:3E:D5:61:F5

echo "== 1. Sistema =="
echo "   kernel: $(uname -r)"
echo "   encendido desde: $(uptime -p 2>/dev/null || uptime)"

echo "== 2. Drivers cargados =="
if lsmod | grep -q '^brtusb'; then echo "   brtusb: SI"; else echo "   brtusb: NO"; fi
if lsmod | grep -q '^btusb'; then echo "   btusb:  SI (no deberia)"; else echo "   btusb:  no"; fi

echo "== 3. Modulo instalado =="
modinfo -n brtusb 2>&1
dkms status brtusb 2>&1 | head -3

echo "== 4. Energia del pincho =="
cat /sys/bus/usb/devices/1-7/power/control 2>&1
cat /sys/bus/usb/devices/1-7/power/runtime_status 2>&1

echo "== 5. Adaptador =="
timeout 10 bluetoothctl list 2>&1
hciconfig hci0 2>&1 | head -3

echo "== 6. Encendiendo =="
timeout 20 bluetoothctl power on 2>&1 | tail -2
bluetoothctl show 2>&1 | grep -E 'Powered|PowerState'

echo "== 7. Conectando al movil =="
timeout 25 bluetoothctl connect "$MAC" 2>&1 | tail -3
sleep 2
bluetoothctl info "$MAC" 2>&1 | grep -E 'Connected|ServicesResolved'

echo "== 8. Vigilancia 20 s =="
for i in 5 10 15 20; do
	sleep 5
	printf "   %2s s: " "$i"
	bluetoothctl info "$MAC" 2>&1 | grep -oE 'Connected: (yes|no)' || echo "(sin datos)"
done

echo "== 9. Contadores =="
hciconfig hci0 2>&1 | tail -2

echo "== 10. Errores del kernel =="
journalctl -k -b 2>&1 | grep -iE 'hci0|brtusb|usb 1-7' | tail -10
