<!-- SPDX-License-Identifier: BSD-2-Clause-Patent -->

**Full documentation available at:**
> https://github.bootable.wiki/bwbundle/

## What is BWBundle?

BWBundle is a pre-configured multi-boot system designed to simplify the process of creating bootable USB drives. It combines GRUB2 configurations and essential EFI tools into a ready-to-use package. ISO files are not included and must be downloaded separately.

## Contents

The bundle includes GRUB configuration files that provide a complete boot menu with support for multiple Linux distributions and system utilities. Including some of the following tools.

| Name | Purpose |
|---|---|
| MokManager | Enroll hashes of the other tools under Secure Boot |
| KeyTool | View Secure Boot keys & remove enrolled keys or hashes |
| Netboot.xyz | Boot into a variety of distros over the ethernet port |
| Memtest86+ | Test the memory of your PC |
| UEFI Shell | Basic environment to run other EFI programs, copy data, edit text files |
| Rufus Driver | NTFS / exFAT booting support, requires two partitions |
| SecureBootRecovery | Verify & install the Microsoft UEFI CA 2023 |

## Key Features

BWBundle uses glob patterns to automatically detect ISO files and EFI binaries, provides clear warnings when tools require Secure Boot to be disabled, and offers multiple boot modes including standard, compatibility, and RAM-boot options. A built-in system information menu displays CPU, motherboard, BIOS, and Secure Boot status. MokManager is included for enrolling unsigned EFI binaries when Secure Boot is enabled.

## Requirements

UEFI motherboard (Secure Boot may need to be disabled for some tools), USB flash drive (8GB+ recommended for full functionality), and basic understanding of GRUB and EFI booting.

## Usage

Copy the BWBundle contents to the root of a FAT32-formatted USB drive. The GRUB configurations will automatically detect and present menu entries for any matching ISO files or EFI binaries present on the drive.

## Contributions/Ways to help

Ask questions, in order to improve I need feedback, if something needs a better explanation let me know.

Finding a way to load large loopbacks on Debian builds of GRUB in Secure Boot. I was able to create loopbacks for gparted-live & clonezilla-live, but could not create for MXLinux or LMDE. I forgot the exact error but it's from GRUB trying to create a large loopback.

Debian netinst ISO not loading correctly.

## See also

- [EFI/readme.txt](EFI/readme.txt) — directory layout and binary origins
- [BWBundle documentation](https://github.bootable.wiki/bwbundle/) — tested ISOs, full feature list, and updates
