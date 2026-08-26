#!/usr/bin/bash

set -ouex pipefail


# Temporary RPM database diagnostics.
check_rpmdb() {
    echo
    echo "============================================================"
    echo "RPM DATABASE CHECK: $1"
    echo "============================================================"

    rpmdb --verifydb
    rpm -qa >/dev/null

    echo "--- lxcfs status ---"
    rpm -q lxcfs || true

    echo "RPM DATABASE CHECK PASSED: $1"
    echo "============================================================"
    echo
}


# CHECK 1:
# Test the RPM database exactly as received from upstream Bazzite,
# before we modify anything.
check_rpmdb "01 - UPSTREAM BAZZITE BASE"


# Copy repository-controlled system files into the image.
cp -avf /ctx/system_files/. /


# Import repository keys before non-interactive package installation.
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
rpm --import https://packages.gundulabs.com/keys/gundulabs-repo.asc


# CHECK 2:
# rpm --import writes GPG package information into the RPM database,
# so verify that the imports did not damage it.
check_rpmdb "02 - AFTER RPM KEY IMPORTS"


# COPR support is required for the libjpeg8 compatibility package used by
# the existing Pantum vendor binaries.
dnf5 install -y \
    dnf5-plugins \
    jq

/ctx/install-image-trust.sh \
    "ghcr.io/iegorch86/family-bazzite"

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
    sane-backends \
    sane-backends-drivers-scanners \
    simple-scan \
    seahorse \
    libjpeg8 \
    libjpeg-turbo


# CHECK 3:
# Verify after our normal application/package transaction.
check_rpmdb "03 - AFTER NATIVE PACKAGE INSTALL"


# Native KVM/QEMU/libvirt/virt-manager virtualization stack.
dnf5 group install -y virtualization


# CHECK 4:
# This is the particularly important checkpoint because this transaction
# produced the swtpm-selinux/scriptlet warnings in the failed build.
check_rpmdb "04 - AFTER VIRTUALIZATION INSTALL"


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


# CHECK 5:
# Final check immediately before build.sh finishes and the image proceeds
# to the later ostree-rechunk stage.
check_rpmdb "05 - FINAL BUILD.SH CHECK"
