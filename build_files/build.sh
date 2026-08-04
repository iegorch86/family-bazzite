#!/usr/bin/bash

set -ouex pipefail

# Copy repository-controlled system files into the image.
cp -avf /ctx/system_files/. /

# Import repository keys before non-interactive package installation.
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
rpm --import https://packages.gundulabs.com/keys/gundulabs-repo.asc

# COPR support is required for the libjpeg8 compatibility package used by
# the existing Pantum vendor binaries.
dnf5 install -y dnf5-plugins

dnf5 -y copr enable aflyhorse/libjpeg

# Native applications and printer/scanner dependencies.
dnf5 install -y \
    brave-browser \
    gaze \
    gaze-gui \
    gaze-gnome-extension \
    cups \
    cups-client \
    cups-filters \
    system-config-printer \
    sane-backends \
    sane-backends-drivers-scanners \
    simple-scan \
    seahorse \
    libjpeg8 \
    libjpeg-turbo

# Do not leave the temporary compatibility COPR enabled in the final system.
dnf5 -y copr disable aflyhorse/libjpeg

# Enable normal system services. Do not select Gaze's global authselect profile.
systemctl enable gazed.service
systemctl enable cups.service

# Ensure copied executable vendor filters remain executable.
find /usr/lib/cups/filter -maxdepth 1 -type f -name 'pt*' \
    -exec chmod 0755 {} + || true

find /usr/lib/cups/filter -maxdepth 1 -type f -name 'rastertoPantum*' \
    -exec chmod 0755 {} + || true

chmod 0755 /opt/pantum/bin/ptqpdf

# Remove package-manager caches from the final image layer.
dnf5 clean all
