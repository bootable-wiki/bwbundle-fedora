SPDX-License-Identifier: BSD-2-Clause-Patent

Layout explained
.
├── boot
│   ├── bootx64.efi         secureboot shim from Fedora (includes Microsoft CA 2023)
│   ├── grubx64.efi         grub from Fedora (signed with Fedora CA / Microsoft KEK)
│   └── mmx64.efi           mokmanager from Fedora
├── readme.txt
├── Rufus
│   ├── bootx64.efi         uefi ntfs from pbatard
│   ├── exfat_x64.efi
│   └── ntfs_x64.efi
├── tool
│   ├── certificates
│   │   ├── db
│   │   │   ├── DBUpdate2024.auth     [DB] Windows UEFI CA 2023 (signed ESL)
│   │   │   ├── DBUpdate3P2023.auth   [DB] Microsoft UEFI CA 2023 (signed ESL)
│   │   │   └── DBUpdateOROM2023.auth [DB] Option ROM UEFI CA 2023 (signed ESL)
│   │   ├── dbx
│   │   │   ├── DBXUpdate.auth        [DBX] Standard revocation list
│   │   │   ├── DBXUpdate2024.auth    [DBX] Revoke Windows Production PCA 2011
│   │   │   └── DBXUpdateSVN.auth     [DBX] Bootmgr SVN update
│   ├── KeyTool.efi         advanced secure boot management from Fedora (efitools)
│   ├── netboot.xyz.efi     ethernet based bootloader from netboot.xyz team
│   ├── SecureBootRecovery.efi verify & install the Microsoft UEFI CA 2023
│   └── shellx64.efi        uefi shell enviroment from pbatard / edk2
└── fedora
    ├── config
    │   ├── fedora.cfg      boots Fedora Workstation & netinst ISOs
    │   ├── otherlinux.cfg  for Arch, Ventoy
    │   ├── system-specifications.cfg  hardware-details menu from Ventoy hwinfo.cfg
    │   ├── tool.cfg        generates menu for tools binaries
    │   └── ubuntu.cfg      boots Ubuntu-based distros (Mint, Elementary, Zorin, etc)
    └── grub.cfg            main menu — sources files from config/ subdirectory
