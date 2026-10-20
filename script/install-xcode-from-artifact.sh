#!/bin/bash
# Installs an Xcode archived by .github/workflows/extract-xcode.yml and makes it the active
# developer directory.
#
# Usage: script/install-xcode-from-artifact.sh <unzipped-artifact-dir>
#
# Undo with: sudo xcode-select -s /Library/Developer/CommandLineTools
set -euo pipefail

dir="${1:?usage: $0 <unzipped-artifact-dir>}"
cd "$dir"

shasum -a 256 -c SHA256SUMS
name=$(sed -n 1p xcode-info.txt)
echo "Archive: $name (macOS SDK $(sed -n 2p xcode-info.txt), $(sed -n 3p xcode-info.txt))"
dest="/Applications/$name.app"
if [ -e "$dest" ]; then
    echo "$dest already exists" >&2
    exit 1
fi

read -rs -p "Archive passphrase: " XCODE_ARCHIVE_PASSPHRASE
echo
export XCODE_ARCHIVE_PASSPHRASE
sudo -v # Ask for the sudo password now rather than in the middle of the pipeline

cat "$name".tar.zst.enc.part-* \
    | openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass env:XCODE_ARCHIVE_PASSPHRASE \
    | zstd -d \
    | sudo tar -xf - -C /Applications

sudo xattr -dr com.apple.quarantine "$dest" 2> /dev/null || true
sudo xcode-select -s "$dest/Contents/Developer"
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch

xcodebuild -version
echo "macOS SDK $(xcrun --sdk macosx --show-sdk-version), $(swift --version 2>&1 | grep -o 'swiftlang-[0-9.]*')"
