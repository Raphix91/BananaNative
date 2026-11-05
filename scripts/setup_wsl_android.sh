#!/bin/bash
# Sets up an Ubuntu (WSL2) machine to build the Android APK and pack games: JDK 17, CMake, Ninja, zsh, the .NET 10 SDK, the Android SDK (platform 36,
# NDK 28.2.13676358, CMake 3.22.1) and a micromamba environment (Python 3.14, spirv-tools, Capstone 5, lz4). Then copies this repository into the Linux file system.
# Usage, from WSL:  bash /mnt/c/<path to this repository>/scripts/setup_wsl_android.sh
# Installs into $HOME (~/android-sdk, ~/.dotnet, ~/micromamba, ~/BananaNative); the Android SDK licences are shown for you to accept.
set -euo pipefail
SRC=$(cd "$(dirname "$0")/.." && pwd)
SDK=$HOME/android-sdk
NDK_VER=28.2.13676358
REPO=$HOME/BananaNative

echo "== System packages"
sudo apt-get update
sudo apt-get install -y openjdk-17-jdk-headless zsh ninja-build cmake curl unzip zip bzip2 git rsync build-essential python3 perl

echo "== .NET 10 SDK"
if [ ! -x "$HOME/.dotnet/dotnet" ]; then
  curl -sSfL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
  bash /tmp/dotnet-install.sh --channel 10.0 --install-dir "$HOME/.dotnet"
fi

echo "== Android SDK"
if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  mkdir -p "$SDK/cmdline-tools"
  curl -sSfL https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -o /tmp/cmdline-tools.zip
  rm -rf "$SDK/cmdline-tools/latest" /tmp/cmdline-tools-x && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-x
  mv /tmp/cmdline-tools-x/cmdline-tools "$SDK/cmdline-tools/latest"
fi
SM="$SDK/cmdline-tools/latest/bin/sdkmanager --sdk_root=$SDK"
$SM --licenses
$SM "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;$NDK_VER" "cmake;3.22.1"

echo "== Python environment (micromamba)"
if [ ! -x "$HOME/.local/bin/micromamba" ]; then
  mkdir -p "$HOME/.local/bin"
  curl -sSfL https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xj -C "$HOME/.local" bin/micromamba
fi
[ -d "$HOME/micromamba/envs/bananative" ] || "$HOME/.local/bin/micromamba" create -y -p "$HOME/micromamba/envs/bananative" -f "$SRC/android/environment.yml"

echo "== Repository → $REPO"
mkdir -p "$REPO"
rsync -a --delete --exclude '.gradle/' --exclude 'build/' --exclude 'out/' "$SRC/" "$REPO/"
find "$REPO" -name '*.sh' -exec chmod +x {} +
chmod +x "$REPO/android/app/gradlew"
echo "sdk.dir=$SDK" > "$REPO/android/app/local.properties"

echo "== Environment (~/.bananative_env, sourced from ~/.bashrc)"
cat > "$HOME/.bananative_env" <<EOF
export JAVA_HOME=\$(dirname \$(dirname \$(readlink -f \$(command -v javac))))
export ANDROID_HOME=$SDK
export ANDROID_NDK_HOME=$SDK/ndk/$NDK_VER
export DOTNET_ROOT=\$HOME/.dotnet
export PATH=\$HOME/micromamba/envs/bananative/bin:\$HOME/.dotnet:\$HOME/.local/bin:$SDK/platform-tools:\$PATH
EOF
grep -q bananative_env "$HOME/.bashrc" || echo '. "$HOME/.bananative_env"' >> "$HOME/.bashrc"
. "$HOME/.bananative_env"

echo "== Check"
java -version 2>&1 | head -1
dotnet --version
python3 -c 'import sys, capstone, lz4, compression.zstd; print("python", sys.version.split()[0], "capstone", capstone.__version__)'
spirv-val --version | head -1
ls -d "$ANDROID_NDK_HOME"
echo "Ready. Next, in a new WSL terminal:"
echo "  cd ~/BananaNative && android/ondevice/build.sh ~/nx-work"
echo "  cd android/app && ./gradlew -PnxPackStage=\$HOME/nx-work/stage -PnxGames=040074A01BF12000,0400A3A01EE4C000 apk"
