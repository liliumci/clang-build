#!/usr/bin/env bash

set -eo pipefail

# Get GitHub Release Script
GH_RELEASE_SH="https://raw.githubusercontent.com/herobuxx/scripts/main/github/upload_release"
curl -o upload_release.sh $GH_RELEASE_SH

# Set a directory
DIR="$(pwd)"
BUILD_LOG="$DIR/build_log.txt"
LLVM_BUILDATE=$(date +'%Y%m%d')

GH_RELEASE_SH=$DIR/upload_release.sh

# Function to show an informational message
msg() {
    echo -e "\033[0;36m$*\033[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

# Telegram Setup
git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram

TELEGRAM="$DIR/Telegram/telegram"
send_msg() {
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

send_file() {
    "${TELEGRAM}" -H \
    -f "$1" \
    "$2"
}

# Telegram: Build triggered!
send_msg "<B>Lilium Toolchain Build Started!</b>"$'\n'$'\n'"Date: $(date)"

# Install dependency
msg "========================================="
msg "== Installing bullding dependencies    =="
msg "========================================="
bash ci.sh deps

# Build LLVM
msg "========================================="
msg "== Building LLVM                       =="
msg "========================================="
./build-llvm.py \
    --assertions \
    --build-stage1-only \
    --build-target distribution \
    --install-target distribution \
    --vendor-string "Lilium" \
    --bolt \
    --final \
    --defines LLVM_PARALLEL_COMPILE_JOBS="${nproc}" LLVM_PARALLEL_LINK_JOBS="${nproc}" CMAKE_C_FLAGS="-O2" CMAKE_CXX_FLAGS="-O2" \
    --projects clang compiler-rt lld polly \
    --targets ARM AArch64 X86 \
    --lto thin \
    --pgo llvm \
    --quiet-cmake \
    --install-folder "install" \
    --no-update | tee "${BUILD_LOG}"

# Verify clang get built
[ ! -f install/bin/clang* ] && {
    err "========================================="
    err "== Failed building LLVM                 =="
    err "========================================="
        send_file "$BUILD_LOG" "<b>Lilium Toolchain Build Failed!</b>"
	exit 1
}

# Build binutils
msg "========================================="
msg "== Building binutils                   =="
msg "========================================="
./build-binutils.py \
    --install-folder "install" \
    --targets arm aarch64 x86_64
    
# Remove unused products
msg "========================================="
msg "== Preparing binaries                  =="
msg "========================================="
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
echo "Stripping remaining products..."
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip ${f: : -1}
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
echo "Setting library load paths for portability..."
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath '$ORIGIN/../lib' "$bin"
done

# Setup Release Repository
mkdir product
rm -rf product/*
mv install/* product/

# Create Commit
cd product/

msg "========================================="
msg "== Compressing output                  =="
msg "========================================="
# Compress Everythng
tar -czvf lilium_clang-$LLVM_BUILDATE.tar.gz *

# Verify clang get built
[ ! -f lilium_clang-*.tar.gz ] && {
    err "========================================="
    err "== Output missing!                     =="
    err "========================================="
        send_file "$BUILD_LOG" "<b>Lilium Toolchain Build Failed!</b>"
	exit 1
}

msg "========================================="
msg "== Create and upload to GitHub Release =="
msg "========================================="
# Upload Build Artifact to GitHub Release
bash $GH_RELEASE_SH "$LLVM_BUILDATE" "$GH_TOKEN" "liliumproject" "clang" "lilium_clang-$LLVM_BUILDATE.tar.gz"

# Send Notification
GH_RELEASE_LINK="https://github.com/liliumproject/clang/releases/tag/$LLVM_BUILDATE"
send_msg "<B>Lilium Toolchain Build Complete!</b>"$'\n'$'\n'"<a href='${GH_RELEASE_LINK}'>Download</a>"

msg "========================================="
msg "== Build completed!                    =="
msg "========================================="