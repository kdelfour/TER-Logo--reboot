#!/usr/bin/env bash
# Construit les paquets .deb et .rpm de TER Logo Reboot.
#
#   scripts/package.sh            # compile puis empaquette
#   SKIP_BUILD=1 scripts/package.sh
#
# Les paquets sont déposés dans dist/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP=ter-logo-reboot
APP_ID=io.github.kdelfour.TerLogoReboot
VERSION="${VERSION:-$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)}"
MAINTAINER="${MAINTAINER:-Kevin Delfour <kdelfour@users.noreply.github.com>}"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
DIST="$ROOT/dist"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ "${SKIP_BUILD:-0}" != 1 ]]; then
  flutter build linux --release
fi
[[ -x "$BUNDLE/$APP" ]] || { echo "Bundle introuvable : $BUNDLE" >&2; exit 1; }

echo "==> Préparation de l'arborescence ($VERSION)"
STAGE="$WORK/stage"
install -d "$STAGE/opt/$APP" "$STAGE/usr/bin" "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/metainfo" "$STAGE/usr/share/mime/packages" "$STAGE/usr/share/doc/$APP" \
  "$STAGE/usr/share/icons/hicolor/scalable/apps"
cp -a "$BUNDLE/." "$STAGE/opt/$APP/"
# Les plugins Flutter gardent un RUNPATH vers le dossier de compilation :
# on le remplace par $ORIGIN (les bibliothèques sont côte à côte).
if command -v patchelf >/dev/null; then
  for so in "$STAGE/opt/$APP"/lib/*.so; do
    if readelf -d "$so" | grep -q RUNPATH; then patchelf --set-rpath '$ORIGIN' "$so"; fi
  done
else
  echo "Attention : patchelf absent, RUNPATH des plugins non corrigé" >&2
fi
ln -s "/opt/$APP/$APP" "$STAGE/usr/bin/$APP"
install -m 644 "packaging/linux/$APP_ID.desktop" "$STAGE/usr/share/applications/"
install -m 644 "packaging/linux/$APP_ID.metainfo.xml" "$STAGE/usr/share/metainfo/"
install -m 644 "packaging/linux/$APP-mime.xml" "$STAGE/usr/share/mime/packages/$APP.xml"
install -m 644 packaging/linux/icons/ter-logo-reboot.svg "$STAGE/usr/share/icons/hicolor/scalable/apps/$APP_ID.svg"
for size in 16 24 32 48 64 128 256 512; do
  install -D -m 644 "packaging/linux/icons/$size.png" "$STAGE/usr/share/icons/hicolor/${size}x${size}/apps/$APP_ID.png"
done
install -m 644 README.md LICENSE "$STAGE/usr/share/doc/$APP/"
install -d "$STAGE/usr/share/$APP"
cp -a examples "$STAGE/usr/share/$APP/exemples"
find "$STAGE" -type d -exec chmod 755 {} +

mkdir -p "$DIST"

echo "==> Paquet .deb"
DEB="$WORK/deb"
cp -a "$STAGE" "$DEB"
install -d "$DEB/DEBIAN"
SIZE_KB=$(du -sk "$DEB" | cut -f1)
cat > "$DEB/DEBIAN/control" <<CONTROL
Package: $APP
Version: $VERSION
Section: education
Priority: optional
Architecture: amd64
Maintainer: $MAINTAINER
Installed-Size: $SIZE_KB
Depends: libgtk-3-0t64 | libgtk-3-0, libepoxy0, libegl1, libstdc++6, libc6 (>= 2.34)
Homepage: https://github.com/kdelfour/TER-Logo--reboot
Description: Interpréteur Logo francophone pour le bureau
 TER Logo Reboot est un interpréteur Logo en français : éditeur avec
 coloration, console interactive, tortue animée, télécommande pour les
 plus jeunes et export des dessins en PNG et SVG.
CONTROL
DEB_FILE="$DIST/${APP}_${VERSION}_amd64.deb"
dpkg-deb --root-owner-group -Zxz --build "$DEB" "$DEB_FILE" >/dev/null
echo "    $DEB_FILE"

echo "==> Paquet .rpm"
RPMTOP="$WORK/rpmbuild"
mkdir -p "$RPMTOP"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
rpmbuild -bb --quiet \
  --define "_topdir $RPMTOP" \
  --define "app_version $VERSION" \
  --define "stagedir $STAGE" \
  --define "_build_id_links none" \
  packaging/linux/ter-logo-reboot.spec
RPM_FILE="$(find "$RPMTOP/RPMS" -name '*.rpm' | head -1)"
cp "$RPM_FILE" "$DIST/"
echo "    $DIST/$(basename "$RPM_FILE")"
