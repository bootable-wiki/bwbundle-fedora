<!-- SPDX-License-Identifier: BSD-2-Clause-Patent -->

**Full documentation available at:**
> https://github.bootable.wiki/bwbundle/

## What is BWBundle?

BWBundle is a pre-configured multi-boot system designed to simplify the process of creating bootable USB drives. It combines GRUB2 configurations and essential EFI tools into a ready-to-use package. ISO files are not included and must be downloaded separately.

## Contents

The bundle includes GRUB configuration files that provide a complete boot menu for Fedora installation ISOs and Secure Boot management utilities.

| Name | Purpose |
|---|---|
| MokManager | Enroll hashes of the other tools under Secure Boot |
| KeyTool | View Secure Boot keys & remove enrolled keys or hashes |

## Key Features

BWBundle uses glob patterns to automatically detect Fedora ISO files and EFI binaries, with boot modes including standard, compatibility, and RAM-boot options. MokManager and KeyTool are included for managing Secure Boot enrollment.

## Requirements

UEFI motherboard (Secure Boot may need to be disabled for some tools), USB flash drive (8GB+ recommended for full functionality), and basic understanding of GRUB and EFI booting.

## Usage

Copy the BWBundle contents to the root of a FAT32-formatted USB drive. The GRUB configurations will automatically detect and present menu entries for any matching ISO files or EFI binaries present on the drive.

## Contributions/Ways to help

Ask questions, in order to improve I need feedback, if something needs a better explanation let me know.

## See also

- [EFI/readme.txt](EFI/readme.txt) — directory layout and binary origins
- [BWBundle documentation](https://github.bootable.wiki/bwbundle/) — tested ISOs, full feature list, and updates
