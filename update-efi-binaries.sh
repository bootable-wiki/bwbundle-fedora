#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause-Patent

set -euo pipefail

cd "$(dirname "$0")"
mkdir -p EFI/boot EFI/tool EFI/Rufus

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ---- Fedora release to track (overridable) ----
FEDORA_VER="${FEDORA_VER:-44}"

# ---- Helper: download a signed EFI binary from Fedora's repos ----
# Usage: fetch_fedora_efi <rpm-name> <path-inside-rpm> <destination>
fetch_fedora_efi() {
    local pkg="$1" src_path="$2" dst="$3"

    echo ">>> $pkg"

    # Query Fedora Koji for the latest binary RPM URL
    local rpm_url
    rpm_url=$(python3 - "$pkg" "$FEDORA_VER" <<'PYEOF' 2>/dev/null
import sys, xmlrpc.client

target_pkg = sys.argv[1]   # binary package name, e.g. shim-x64
ver = sys.argv[2]

# Map binary package name to source package name for Koji lookup
src_map = {
    'shim-x64': 'shim',
    'grub2-efi-x64-signed': 'grub2',
    'efitools': 'efitools',
}
src_pkg = src_map.get(target_pkg, target_pkg)

proxy = xmlrpc.client.ServerProxy('https://koji.fedoraproject.org/kojihub')

for tag in (f'f{ver}-updates', f'f{ver}'):
    try:
        result = proxy.getLatestRPMS(tag, src_pkg)
    except Exception:
        continue
    if not result or not result[0]:
        continue
    build_id = result[0][0].get('build_id')
    if not build_id:
        continue
    # List all RPMs from this build
    rpms = proxy.listBuildRPMs(build_id)
    for r in rpms:
        if r.get('name') == target_pkg and r.get('arch') == 'x86_64':
            nvr = r['nvr']
            # parse version and release from NVR (name-version-release)
            parts = nvr.split('-')
            rel = parts[-1]
            ver_part = parts[-2]
            rpm_url = f'https://kojipkgs.fedoraproject.org/packages/{src_pkg}/{ver_part}/{rel}/x86_64/{nvr}.x86_64.rpm'
            print(rpm_url)
            sys.exit(0)

sys.exit(1)
PYEOF
)

    [ -z "$rpm_url" ] && { echo "  FAILED" >&2; return 1; }

    local rpm_file="$tmp/${pkg}.rpm"
    echo "  Fetching $rpm_url"
    curl -fL "$rpm_url" -o "$rpm_file"

    # Extract RPM
    local edir="$tmp/extract_${pkg}"
    mkdir -p "$edir"
    if command -v bsdtar &>/dev/null; then
        bsdtar -xf "$rpm_file" -C "$edir" 2>/dev/null
    elif command -v rpm2cpio &>/dev/null; then
        rpm2cpio "$rpm_file" 2>/dev/null | cpio -idm -D "$edir" 2>/dev/null
    else
        echo "ERROR: need bsdtar (libarchive-tools) or rpm2cpio" >&2
        return 1
    fi

    # Locate the desired file inside the extracted tree
    found=$(find "$edir" -path "*/${src_path}" -type f 2>/dev/null | head -1)
    if [ -z "$found" ]; then
        echo "  WARNING: ${src_path} not found in $pkg, searching..."
        found=$(find "$edir" -name "*.efi" -type f 2>/dev/null | head -5)
        echo "  Available EFI files: $found"
        return 1
    fi
    cp "$found" "$dst"
    echo "  -> $dst"
}

# ---- 1. shim-x64: bootx64.efi + mmx64.efi (MokManager) ----
fetch_fedora_efi "shim-x64" "usr/share/shim/x64/shimx64.efi" "EFI/boot/bootx64.efi"
fetch_fedora_efi "shim-x64" "usr/share/shim/x64/mmx64.efi" "EFI/boot/mmx64.efi"

# ---- 2. grub2-efi-x64-signed: grubx64.efi ----
fetch_fedora_efi "grub2-efi-x64-signed" "usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" "EFI/boot/grubx64.efi"

# ---- 3. netboot.xyz.efi ----
echo ">>> netboot.xyz"
curl -fL https://boot.netboot.xyz/ipxe/netboot.xyz.efi -o EFI/tool/netboot.xyz.efi

# ---- 4. memtest86+ ----
echo ">>> memtest86+"
ver=$(curl -fsSL https://api.github.com/repos/memtest86plus/memtest86plus/releases/latest | python3 -c 'import sys,json;print(json.load(sys.stdin)["tag_name"])')
curl -fL "https://memtest.org/download/$ver/mt86plus_${ver#v}.binaries.zip" -o "$tmp/m.zip"
unzip -o "$tmp/m.zip" '*x86_64*' -d .

# ---- 5. Rufus UEFI:NTFS ----
echo ">>> Rufus UEFI:NTFS"
curl -fL https://raw.githubusercontent.com/pbatard/rufus/master/res/uefi/uefi-ntfs.img -o "$tmp/r.img"
7z e -y -oEFI/Rufus "$tmp/r.img" EFI/Boot/bootx64.efi EFI/Rufus/ntfs_x64.efi EFI/Rufus/exfat_x64.efi >/dev/null

# ---- 6. UEFI Shell ----
echo ">>> UEFI Shell"
curl -fL https://github.com/pbatard/UEFI-Shell/releases/latest/download/shellx64.efi -o EFI/tool/shellx64.efi

# ---- 7. KeyTool.efi (from Fedora's efitools) ----
echo ">>> KeyTool.efi"
fetch_fedora_efi "efitools" "usr/lib/efitools/x86_64-efi/KeyTool.efi" "EFI/tool/KeyTool.efi" \
    || fetch_fedora_efi "efitools" "usr/lib64/efitools/x86_64-efi/KeyTool.efi" "EFI/tool/KeyTool.efi"

# ---- 8. SecureBootRecovery.efi (from Microsoft KB5063878) ----
echo ">>> SecureBootRecovery.efi"
sbr="$tmp/SecureBootRecovery.efi"
curl -fL https://msdl.microsoft.com/download/symbols/SecureBootRecovery.efi/A867E58360000/SecureBootRecovery.efi -o "$sbr"
echo "48dfb0cd5af49fa8528e73f3968fd944f1f41a6c58ec9e713f09610c585166bf  $sbr" | sha256sum -c -
cp "$sbr" EFI/tool/

# ---- Build release zip ----
export TZ=America/Los_Angeles
DATETIME=$(date +"%Y%m%d_%H%M")
VERSION="bwbundle_alpha_${DATETIME}"
echo "$VERSION" > version.txt
zip -r "${VERSION}.zip" . -x '.git/*' -x '.github/*' -x 'update-efi-binaries.sh' -x '.gitignore'
