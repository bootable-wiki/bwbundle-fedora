SPDX-License-Identifier: BSD-2-Clause-Patent

Layout explained
.
├── KeyTool.efi          advanced secure boot management from Ubuntu (efitools)
├── boot
│   ├── bootx64.efi      secureboot shim from Fedora (includes Microsoft CA 2023)
│   ├── grubx64.efi      grub from Fedora (signed with Fedora CA / Microsoft KEK)
│   └── mmx64.efi        mokmanager from Fedora
├── certs
│   ├── readme.txt
│   ├── db
│   │   ├── DBUpdate2024.auth     [DB] Windows UEFI CA 2023 (signed ESL)
│   │   ├── DBUpdate3P2023.auth   [DB] Microsoft UEFI CA 2023 (signed ESL)
│   │   └── DBUpdateOROM2023.auth [DB] Option ROM UEFI CA 2023 (signed ESL)
│   └── dbx
│       ├── DBXUpdate.auth        [DBX] Standard revocation list
│       ├── DBXUpdate2024.auth    [DBX] Revoke Windows Production PCA 2011
│       └── DBXUpdateSVN.auth     [DBX] Bootmgr SVN update
├── fedora
│   └── grub.cfg         single config - Fedora ISOs + root .efi + utilities
└── readme.md
