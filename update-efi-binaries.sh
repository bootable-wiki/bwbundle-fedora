#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause-Patent

set -euo pipefail

cd "$(dirname "$0")"
mkdir -p EFI/boot EFI/tool EFI/Rufus

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ---- Fedora release to track (overridable) ----
# The shim must include Microsoft CA 2023.  Fedora 45+ has this; older
# releases ship a shim signed only with the 2011 CA.  You can override
# via the FEDORA_VER environment variable.
FEDORA_VER="${FEDORA_VER:-45}"

# ---- Helper: download a signed EFI binary from Fedora's repos ----
# Usage: fetch_fedora_efi <rpm-name> <path-inside-rpm> <destination>
fetch_fedora_efi() {
    local pkg="$1" src_path="$2" dst="$3"

    echo ">>> $pkg"

    # Query Fedora Koji for the latest binary RPM URL.
    # Tries multiple Fedora releases so that even if FEDORA_VER points to
    # an older release, we can grab the shim from a newer one (needed for
    # Microsoft CA 2023 support).
    local rpm_url
    rpm_url=$(python3 - "$pkg" "$FEDORA_VER" <<'PYEOF' 2>/dev/null
import sys, xmlrpc.client

target_pkg, ver = sys.argv[1], sys.argv[2]

src_map = {
    'shim-x64':                 ('shim',   ['shim-x64']),
    'grub2-efi-x64-signed':     ('grub2',  ['grub2-efi-x64', 'grub2-efi-x64-signed']),
    'efitools':                 ('efitools', ['efitools']),
}
entry = src_map.get(target_pkg)
if not entry:
    sys.exit(1)
src_pkg, binary_names = entry

proxy = xmlrpc.client.ServerProxy('https://koji.fedoraproject.org/kojihub')

# Try the configured version, then newer releases
for v in (int(ver), int(ver)+1, int(ver)+2):
    for tag in (f'f{v}-updates', f'f{v}'):
        try:
            result = proxy.getLatestRPMS(tag, src_pkg)
        except Exception:
            continue
        if not result or not result[0]:
            continue
        build_id = result[0][0].get('build_id')
        if not build_id:
            continue
        rpms = proxy.listBuildRPMs(build_id)
        for r in rpms:
            if r.get('arch') != 'x86_64':
                continue
            if r.get('name') not in binary_names:
                continue
            nvr = r['nvr']
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
    local target_file="${src_path##*/}"
    found=$(find "$edir" -path "*/${src_path}" -type f 2>/dev/null | head -1)
    if [ -z "$found" ]; then
        found=$(find "$edir" -name "$target_file" -type f 2>/dev/null | head -1)
    fi
    if [ -z "$found" ]; then
        echo "  WARNING: ${src_path}/${target_file} not found, searching for any .efi..."
        found=$(find "$edir" -name "*.efi" -type f 2>/dev/null | head -1)
    fi
    if [ -z "$found" ]; then
        echo "  ERROR: no EFI binary found in $pkg RPM" >&2
        return 1
    fi
    cp "$found" "$dst"
    echo "  -> $dst"
}

# ---- 1. shim-x64: bootx64.efi + mmx64.efi (MokManager) ----
fetch_fedora_efi "shim-x64" "usr/share/shim/x64/shimx64.efi" "EFI/boot/bootx64.efi"
fetch_fedora_efi "shim-x64" "usr/share/shim/x64/mmx64.efi" "EFI/boot/mmx64.efi"

# ---- 2. grub2-efi-x64: grubx64.efi ----
# Fedora ships the signed GRUB in the grub2-efi-x64 subpackage
fetch_fedora_efi "grub2-efi-x64-signed" "grubx64.efi" "EFI/boot/grubx64.efi"

# ---- 3. netboot.xyz.efi ----
echo ">>> netboot.xyz"
curl -fL https://boot.netboot.xyz/ipxe/netboot.xyz.efi -o EFI/tool/netboot.xyz.efi

# ---- 4. memtest86+ ----
echo ">>> memtest86+"
ver=$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/memtest86plus/memtest86plus/releases/latest | python3 -c 'import sys,json;print(json.load(sys.stdin)["tag_name"])')
curl -fL "https://memtest.org/download/$ver/mt86plus_${ver#v}.binaries.zip" -o "$tmp/m.zip"
unzip -o "$tmp/m.zip" '*x86_64*' -d .

# ---- 5. Rufus UEFI:NTFS ----
echo ">>> Rufus UEFI:NTFS"
curl -fL https://raw.githubusercontent.com/pbatard/rufus/master/res/uefi/uefi-ntfs.img -o "$tmp/r.img"
7z e -y -oEFI/Rufus "$tmp/r.img" EFI/Boot/bootx64.efi EFI/Rufus/ntfs_x64.efi EFI/Rufus/exfat_x64.efi >/dev/null

# ---- 6. UEFI Shell ----
echo ">>> UEFI Shell"
curl -fL https://github.com/pbatard/UEFI-Shell/releases/latest/download/shellx64.efi -o EFI/tool/shellx64.efi

# ---- 7. KeyTool.efi (from Ubuntu Noble efitools; Fedora's efitools doesn't ship the EFI binary) ----
echo ">>> KeyTool.efi"
curl -fsSL "https://archive.ubuntu.com/ubuntu/dists/noble/universe/binary-amd64/Packages.xz" | xz -d > "$tmp/pkgs-noble"
efitools=$(awk '/^Package: efitools$/{g=1} g&&/^Filename: /{print$2;exit}' "$tmp/pkgs-noble")
curl -fL "https://archive.ubuntu.com/ubuntu/$efitools" -o "$tmp/efitools.deb"
dpkg-deb -x "$tmp/efitools.deb" "$tmp/efitools"
cp "$tmp/efitools/usr/lib/efitools/x86_64-linux-gnu/KeyTool.efi" EFI/tool/KeyTool.efi

# ---- 8. Secure Boot 2023 certificate updates (signed ESLs for KeyTool) ----
# These Microsoft-signed ESL packages can be loaded via KeyTool.efi (Edit DB → Load)
# to add the 2023 DB certificates without needing Setup Mode.
# Note: KEK 2023 updates are OEM PK-signed so not included here.
echo ">>> Secure Boot 2023 certificate packages"
mkdir -p EFI/tool/certificates/db EFI/tool/certificates/dbx
BASE="https://github.com/microsoft/secureboot_objects/raw/main/PostSignedObjects"

# DB updates (3x 2023 certificates)
curl -fL "$BASE/Optional/DB/amd64/DBUpdate2024.bin"    -o EFI/tool/certificates/db/DBUpdate2024.auth
curl -fL "$BASE/Optional/DB/amd64/DBUpdate3P2023.bin"  -o EFI/tool/certificates/db/DBUpdate3P2023.auth
curl -fL "$BASE/Optional/DB/amd64/DBUpdateOROM2023.bin" -o EFI/tool/certificates/db/DBUpdateOROM2023.auth

# DBX updates (revoke 2011 + SVN)
curl -fL "$BASE/Optional/DBX/amd64/DBXUpdate2024.bin"  -o EFI/tool/certificates/dbx/DBXUpdate2024.auth
curl -fL "$BASE/Optional/DBX/amd64/DBXUpdateSVN.bin"   -o EFI/tool/certificates/dbx/DBXUpdateSVN.auth

# Standard DBX (current revocation list)
curl -fL "$BASE/DBX/amd64/DBXUpdate.bin"               -o EFI/tool/certificates/dbx/DBXUpdate.auth

# ---- 8. SecureBootRecovery.efi (from Microsoft KB5063878) ----
echo ">>> SecureBootRecovery.efi"
sbr="$tmp/SecureBootRecovery.efi"
curl -fL https://msdl.microsoft.com/download/symbols/SecureBootRecovery.efi/A867E58360000/SecureBootRecovery.efi -o "$sbr"
echo "48dfb0cd5af49fa8528e73f3968fd944f1f41a6c58ec9e713f09610c585166bf  $sbr" | sha256sum -c -
cp "$sbr" EFI/tool/

# ---- Build release zip ----
export TZ=America/Los_Angeles
DATETIME=$(date +"%Y%m%d_%H%M")
VERSION="bwbundle-fedora-alpha_${DATETIME}"
echo "$VERSION" > version.txt
zip -r "${VERSION}.zip" . -x '.git/*' -x '.github/*' -x 'update-efi-binaries.sh' -x '.gitignore'
