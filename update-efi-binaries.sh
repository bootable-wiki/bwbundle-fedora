#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause-Patent

set -euo pipefail

cd "$(dirname "$0")"
mkdir -p EFI/boot EFI/tool EFI/Rufus

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Query Canonical's meta-release-lts file for the latest LTS codename.
lts=$(curl -fsSL https://changelogs.ubuntu.com/meta-release-lts | grep '^Dist:' | tail -1 | awk '{print $2}')

# Download the package index once and parse out the two .deb paths we need.
curl -fsSL "https://archive.ubuntu.com/ubuntu/dists/$lts/main/binary-amd64/Packages.xz" | xz -d > "$tmp/pkgs"
shim=$(awk '/^Package: shim-signed$/{g=1} g&&/^Filename: /{print$2;exit}' "$tmp/pkgs")
grub=$(awk '/^Package: grub-efi-amd64-signed$/{g=1} g&&/^Filename: /{print$2;exit}' "$tmp/pkgs")

# 1. shim-signed → bootx64.efi + mmx64.efi (MokManager)
curl -fL "https://archive.ubuntu.com/ubuntu/$shim" -o "$tmp/shim.deb"; dpkg-deb -x "$tmp/shim.deb" "$tmp/shim"
cp "$tmp/shim/usr/lib/shim/shimx64.efi.signed.latest" EFI/boot/bootx64.efi
cp "$tmp/shim/usr/lib/shim/mmx64.efi" EFI/boot/mmx64.efi

# 2. grub-efi-amd64-signed → grubx64.efi
curl -fL "https://archive.ubuntu.com/ubuntu/$grub" -o "$tmp/grub.deb"; dpkg-deb -x "$tmp/grub.deb" "$tmp/grub"
cp "$tmp/grub/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" EFI/boot/grubx64.efi

# 3. netboot.xyz.efi
curl -fL https://boot.netboot.xyz/ipxe/netboot.xyz.efi -o EFI/tool/netboot.xyz.efi

# 4. memtest86+ — latest version from GitHub, extract only x86_64 binary.
ver=$(curl -fsSL https://api.github.com/repos/memtest86plus/memtest86plus/releases/latest | python3 -c 'import sys,json;print(json.load(sys.stdin)["tag_name"])')
curl -fL "https://memtest.org/download/$ver/mt86plus_${ver#v}.binaries.zip" -o "$tmp/m.zip"
unzip -o "$tmp/m.zip" '*x86_64*' -d .

# 5. Rufus UEFI:NTFS image → signed bootx64.efi, ntfs_x64.efi, exfat_x64.efi
curl -fL https://raw.githubusercontent.com/pbatard/rufus/master/res/uefi/uefi-ntfs.img -o "$tmp/r.img"
7z e -y -oEFI/Rufus "$tmp/r.img" EFI/Boot/bootx64.efi EFI/Rufus/ntfs_x64.efi EFI/Rufus/exfat_x64.efi >/dev/null

# 6. UEFI Shell
curl -fL https://github.com/pbatard/UEFI-Shell/releases/latest/download/shellx64.efi -o EFI/tool/shellx64.efi

# 7. KeyTool.efi from Ubuntu Noble efitools package (Noble is the last release that ships it)
curl -fsSL "https://archive.ubuntu.com/ubuntu/dists/noble/universe/binary-amd64/Packages.xz" | xz -d > "$tmp/pkgs-noble"
efitools=$(awk '/^Package: efitools$/{g=1} g&&/^Filename: /{print$2;exit}' "$tmp/pkgs-noble")
curl -fL "https://archive.ubuntu.com/ubuntu/$efitools" -o "$tmp/efitools.deb"; dpkg-deb -x "$tmp/efitools.deb" "$tmp/efitools"
cp "$tmp/efitools/usr/lib/efitools/x86_64-linux-gnu/KeyTool.efi" EFI/tool/KeyTool.efi

# 8. SecureBootRecovery.efi from KB5063878 (Win11 24H2, build 26100.4946)
sbr="$tmp/SecureBootRecovery.efi"
curl -fL https://msdl.microsoft.com/download/symbols/SecureBootRecovery.efi/A867E58360000/SecureBootRecovery.efi -o "$sbr"
echo "48dfb0cd5af49fa8528e73f3968fd944f1f41a6c58ec9e713f09610c585166bf  $sbr" | sha256sum -c -
cp "$sbr" EFI/tool/

# Build release zip
export TZ=America/Los_Angeles
DATETIME=$(date +"%Y%m%d_%H%M")
VERSION="bwbundle_alpha_${DATETIME}"
echo "$VERSION" > version.txt
zip -r "${VERSION}.zip" . -x '.git/*' -x '.github/*' -x 'update-efi-binaries.sh' -x '.gitignore'
