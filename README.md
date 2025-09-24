# iw4x-updoot
POSIX sh installer/updater for [iw4x](https://iw4x.io)

# Dependencies
- `jq`, `grep`, `sed`, `unzip`, `sha256sum`, `curl`
- Any POSIX-capable shell.
- A legitimate copy of the game, as per usual.

# Usage
* Installing iw4x:

    - Copy this script to your Modern Warfare 2 directory
    - `chmod +x iw4x-updoot.sh`
    - `./iw4x-updoot.sh`
    - Wait for the script to finish running, and play.

* Running cleanup:

If something broke warranting a reinstall, or if you want to wipe this and iw4x from your game, you may run `./iw4x-updoot.sh -c` from the Modern Warfare 2 directory, and the script will clean up all iw4x files as well as its own.

You may then run `./iw4x-updoot.sh` again to perform an installation as if you had just installed MW2.

* Updating:

Just run `./iw4x-updoot.sh`, the same as installation- this script knows where it is because it knows where it isn't.

# What about launching the game?
Add iw4x.exe as a non-steam game via your Steam client, launch from there as per usual with iw4x.

# Will you add Windows support?
Seriously?
