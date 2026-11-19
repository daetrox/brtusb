#!/usr/bin/env bash
# Construye el paquete instalable: dist/brtusb-dkms_<version>_all.deb
# No necesita root: solo escribe en dist/ y en un directorio temporal.
#
#   sudo apt install ./dist/brtusb-dkms_1.1-1_all.deb

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PKG=brtusb-dkms
NAME=brtusb
VER=1.1
REL=1
OUT="$ROOT/dist"
KREL=$(uname -r)

for f in brtusb.c Makefile dkms.conf README.md CHANGELOG.md LICENSE; do
	[ -f "$ROOT/$f" ] || { echo "ERROR: falta $ROOT/$f"; exit 1; }
done

BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
D="$BUILD/${PKG}_${VER}-${REL}_all"
DOC="$D/usr/share/doc/$PKG"

mkdir -p "$D/DEBIAN" "$D/usr/src/$NAME-$VER" \
	"$D/etc/modprobe.d" "$D/etc/modules-load.d" "$DOC"

# Fuente del modulo: DKMS lo compila en cada kernel.
install -m 644 "$ROOT/brtusb.c" "$ROOT/Makefile" "$ROOT/dkms.conf" \
	"$D/usr/src/$NAME-$VER/"

# Configuracion: bloquear btusb y cargar brtusb al arrancar.
install -m 644 "$ROOT/packaging/brtusb.conf" "$D/etc/modprobe.d/$NAME.conf"
install -m 644 "$ROOT/packaging/brtusb.load" "$D/etc/modules-load.d/$NAME.conf"
printf '%s\n' "/etc/modprobe.d/$NAME.conf" \
	"/etc/modules-load.d/$NAME.conf" > "$D/DEBIAN/conffiles"

# Documentacion.
install -m 644 "$ROOT/README.md" "$ROOT/CHANGELOG.md" "$ROOT/LICENSE" "$DOC/"
cat > "$DOC/copyright" <<'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: brtusb
Source: https://github.com/daetrox/brtusb

Files: *
Copyright: 2026 daetrox
License: GPL-2
 El driver se distribuye bajo la GNU General Public License, version 2.
 En un sistema Debian, el texto completo esta en
 /usr/share/common-licenses/GPL-2 y en el fichero LICENSE del paquete.
EOF

install -m 755 "$ROOT/packaging/debian/postinst" "$D/DEBIAN/postinst"
install -m 755 "$ROOT/packaging/debian/prerm" "$D/DEBIAN/prerm"
install -m 755 "$ROOT/packaging/debian/postrm" "$D/DEBIAN/postrm"

# Permisos limpios: directorios 755, ficheros 644 (el umask del usuario no manda).
find "$D" -type d -exec chmod 755 {} +
find "$D" -type f -exec chmod 644 {} +
chmod 755 "$D/DEBIAN/postinst" "$D/DEBIAN/prerm" "$D/DEBIAN/postrm"

SIZE=$(du -sk --exclude=DEBIAN "$D" | cut -f1)
cat > "$D/DEBIAN/control" <<EOF
Package: $PKG
Version: $VER-$REL
Architecture: all
Maintainer: daetrox <228954151+daetrox@users.noreply.github.com>
Installed-Size: $SIZE
Depends: dkms (>= 2.8)
Section: kernel
Priority: optional
Homepage: https://github.com/daetrox/brtusb
Description: driver Bluetooth para el adaptador BARROT 33fa:0001
 Driver HCI USB para el pincho BARROT «USB2.0-BT» (familia BR8554),
 portado del driver de Windows. El driver generico btusb acepta el
 dispositivo por su clase USB pero no consigue inicializarlo
 (Opcode 0x0c03 failed: -110); este driver si lo hace.
 .
 Compilado con DKMS para cada kernel. Se instala como brtusb y se
 impide la carga automatica de btusb, que dejaria el pincho sin
 responder.
EOF

mkdir -p "$OUT"
dpkg-deb --root-owner-group -Zxz --build "$D" \
	"$OUT/${PKG}_${VER}-${REL}_all.deb"

echo "== Paquete creado =="
dpkg-deb -I "$OUT/${PKG}_${VER}-${REL}_all.deb" | sed -n '1,14p'
echo
echo "Instalar:  sudo apt install $OUT/${PKG}_${VER}-${REL}_all.deb"
echo "Kernel actual: $KREL"
