# Paquet RPM construit à partir de l'arborescence préparée par scripts/package.sh.
%global debug_package %{nil}
# Ne pas toucher aux binaires Flutter (le strip casse libapp.so).
%global __os_install_post %{nil}
%global __provides_exclude_from ^/opt/ter-logo-reboot/.*$
%global __requires_exclude ^(libflutter_linux_gtk|libapp|libfile_selector_linux_plugin)\\.so.*$

Name:           ter-logo-reboot
Version:        %{app_version}
Release:        1
Summary:        Interpréteur Logo francophone pour le bureau
License:        MIT
URL:            https://github.com/kdelfour/TER-Logo--reboot
ExclusiveArch:  x86_64
Requires:       gtk3
Requires:       libEGL.so.1()(64bit)

%description
TER Logo Reboot est un interpréteur Logo francophone : éditeur avec
coloration, console interactive, tortue animée, télécommande et export
des dessins en PNG et SVG. Réécriture en Flutter d'un projet de M1
Informatique de l'Université Montpellier II (2007).

%install
cp -a %{stagedir}/. %{buildroot}/

%files
/opt/ter-logo-reboot
/usr/bin/ter-logo-reboot
/usr/share/applications/io.github.kdelfour.TerLogoReboot.desktop
/usr/share/metainfo/io.github.kdelfour.TerLogoReboot.metainfo.xml
/usr/share/mime/packages/ter-logo-reboot.xml
/usr/share/icons/hicolor/*/apps/io.github.kdelfour.TerLogoReboot.png
/usr/share/icons/hicolor/scalable/apps/io.github.kdelfour.TerLogoReboot.svg
/usr/share/doc/ter-logo-reboot
/usr/share/ter-logo-reboot

%post
update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || :
update-mime-database /usr/share/mime >/dev/null 2>&1 || :
touch --no-create /usr/share/icons/hicolor >/dev/null 2>&1 || :

%postun
update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || :
update-mime-database /usr/share/mime >/dev/null 2>&1 || :
