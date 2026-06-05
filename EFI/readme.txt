SPDX-License-Identifier: BSD-2-Clause-Patent

Layout explained
.
├── boot
│   ├── bootx64.efi         secureboot shim from Canonical
│   ├── grubx64.efi         grub from Canonical
│   └── mmx64.efi           mokmanager from Canonical
├── readme.txt
├── Rufus
│   ├── bootx64.efi         uefi ntfs from pbatard
│   ├── exfat_x64.efi
│   └── ntfs_x64.efi
├── tool
│   ├── KeyTool.efi         advanced secure boot management from Canonical
│   ├── netboot.xyz.efi     ethernet based bootloader from netboot.xyz team
│   └── shellx64.efi        uefi shell enviroment from pbatard / edk2
└── ubuntu
    ├── config
    │   ├── otherlinux.cfg  for Fedora, Arch etc
    │   ├── system-specifications.cfg  hardware-details menu from Ventoy hwinfo.cfg
    │   ├── tool.cfg        generates menu for tools binaries
    │   └── ubuntu.cfg      loads Ubuntu based distros like Mint/Elementary
    └── grub.cfg            must have it loads the others from config folder.
