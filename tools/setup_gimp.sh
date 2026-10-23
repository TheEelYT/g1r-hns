#!/usr/bin/env bash
# Pinned official GIMP 3 AppImage; extracted so build hosts do not need FUSE.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tool_dir="$project_root/.tools/gimp"
mkdir -p "$tool_dir"
cd "$tool_dir"
curl -fL --retry 3 https://download.gimp.org/gimp/v3.2/linux/GIMP-3.2.6-x86_64.AppImage -o GIMP.AppImage.part
echo '79ea41bc9b06f78fda181849a9ca8e42d83f1124dedb756f4d52352e2465010f  GIMP.AppImage.part' | sha256sum --check
mv GIMP.AppImage.part GIMP.AppImage
chmod +x GIMP.AppImage
./GIMP.AppImage --appimage-extract >/dev/null
./squashfs-root/AppRun --version
