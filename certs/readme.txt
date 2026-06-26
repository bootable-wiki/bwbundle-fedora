Microsoft-signed Secure Boot 2023 certificate update packages (amd64).

These are Authenticated Variable updates (.auth format) sourced from
Microsoft's secureboot_objects repository.  Each file is a signed EFI
Signature List (ESL) that can be loaded directly by KeyTool.efi.

Use with KeyTool.efi to update DB/DBX without Setup Mode
(load via Edit DB / Edit DBX -> Load -> select the .auth file):

Order to apply (increasing risk):
 1. db/DBUpdate2024.auth     - Add Windows UEFI CA 2023 to DB
 2. db/DBUpdate3P2023.auth   - Add Microsoft UEFI CA 2023 to DB (for shim/Linux)
 3. db/DBUpdateOROM2023.auth - Add Option ROM UEFI CA 2023 to DB
 4. dbx/DBXUpdate.auth       - Update standard revocation list
 5. dbx/DBXUpdateSVN.auth    - Apply Bootmgr SVN update (optional)
 6. dbx/DBXUpdate2024.auth   - Revoke Windows Production PCA 2011 (breaks old boot media)

Source: https://github.com/microsoft/secureboot_objects
