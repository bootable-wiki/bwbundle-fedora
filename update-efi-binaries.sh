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

    # Use Python to discover the RPM URL from Fedora repodata
    local rpm_url
    rpm_url=$(python3 - "$pkg" "$FEDORA_VER" <<'PYEOF' 2>/dev/null
import sys, xml.etree.ElementTree as ET, gzip, subprocess, urllib.request
pkg, ver = sys.argv[1], sys.argv[2]

for repo_type in ('updates', 'releases'):
    base = f'https://mirrors.kernel.org/fedora/{repo_type}/{ver}/Everything/x86_64'
    try:
        repomd = urllib.request.urlopen(f'{base}/repodata/repomd.xml', timeout=30).read()
    except Exception:
        continue

    root = ET.fromstring(repomd)
    ns = 'http://linux.duke.edu/metadata/repo'
    primary_href = None
    for data in root.findall(f'.//{{{ns}}}data'):
        if data.get('type') == 'primary':
            loc = data.find(f'{{{ns}}}location')
            if loc is not None:
                primary_href = loc.get('href')
    if not primary_href:
        continue

    primary_url = f'{base}/{primary_href}'
    try:
        raw = urllib.request.urlopen(primary_url, timeout=30).read()
    except Exception:
        continue

    if primary_href.endswith('.gz'):
        xml_data = gzip.decompress(raw)
    elif primary_href.endswith('.zst'):
        proc = subprocess.run(['zstd', '-d', '-q'], input=raw, capture_output=True)
        xml_data = proc.stdout
        if proc.returncode != 0:
            continue
    elif primary_href.endswith('.xz'):
        proc = subprocess.run(['xz', '-d', '-q'], input=raw, capture_output=True)
        xml_data = proc.stdout
        if proc.returncode != 0:
            continue
    else:
        continue

    root2 = ET.fromstring(xml_data)
    for pkg_el in root2.findall(f'.//{{{ns}}}package'):
        name_el = pkg_el.find(f'{{{ns}}}name')
        if name_el is None or name_el.text != pkg:
            continue
        if pkg_el.get('arch') not in ('x86_64', 'noarch'):
            continue
        loc = pkg_el.find(f'{{{ns}}}location')
        if loc is None:
            continue
        href = loc.get('href', '')
        if not href:
            continue
        print(f'https://mirrors.kernel.org/fedora/{href}')
        sys.exit(0)

print(f'ERROR: package {pkg} not found in Fedora {ver} repos', file=sys.stderr)
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
