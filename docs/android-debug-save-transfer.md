# Keep your colony when switching Android debug builds

The published 0.2.0 and 0.2.1 previews use different signing certificates, as did 0.1.0 and 0.2.0. Android requires removing the old preview when switching between these certificates. **Export your saves while the old preview is still installed.** The transfer covers your campaign, creatures, settings, downloaded puzzles and Library notes.

Use a computer with Python 3 and Android Platform Tools. Enable USB debugging on your phone, connect it and approve the computer. Run `adb devices` to get its serial number. Run the commands below from the project directory, replacing `DEVICE_SERIAL` with that serial. Pick new folder names somewhere you can keep your backups. [Save-transfer helper](../tool/debug_save_transfer.py) · [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools)

## 1. Export the old saves

Open the old preview and visit the Sudoku tab once so both databases exist. Then run this command on the computer. The helper stops the app, snapshots both SQLite databases including committed changes in their write-ahead logs, checks their integrity and records checksums.

```sh
python3 tool/debug_save_transfer.py --device DEVICE_SERIAL export --output sodukromental-old-save
```

Wait for **Validated backup** and keep that folder. You can now remove the old preview, install the new debug APK and launch it. Open its Sudoku tab once.

## 2. Restore into the new preview

```sh
python3 tool/debug_save_transfer.py --device DEVICE_SERIAL restore --input sodukromental-old-save --target-backup sodukromental-before-restore
```

The second folder holds a backup of the new installation as it stood before the restore. The helper checks the incoming databases on the device before replacing them. After **Restore verified on device**, open the game and check your colony and a Library puzzle you remember. Reopen the app once more to confirm your progress. Keep both backup folders until you have checked your saves.
