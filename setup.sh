#!/usr/local/bin/bash -e
# py311-pyyaml py311-mako
NDK_VER="android-ndk-r29"
NDK_BIN="$PWD/$NDK_VER/toolchains/llvm/prebuilt/linux-x86_64/bin"
SDK_VER="28"
CROSS_FILE="android$SDK_VER-aarch64.txt"
WORK_DIR="$PWD"
MESA_BUILD_DIR="$WORK_DIR/mesa-build-android$SDK_VER"
setup_android_ndk() {
    NDK_ZIP="$NDK_VER-linux.zip"
    wget "https://dl.google.com/android/repository/$NDK_ZIP"
    unzip "$NDK_ZIP"
}
[ -d "$NDK_VER" ] || setup_android_ndk
[ -d "mesa" ] || git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa mesa
[ -d "$NDK_BIN" ] || exit

# setup
[ -f "$CROSS_FILE" ] || cat <<EOF >"$CROSS_FILE"
[binaries]
ar = '$NDK_BIN/llvm-ar'
c = ['ccache', '$NDK_BIN/aarch64-linux-android$SDK_VER-clang', '-fomit-frame-pointer', '-Wno-deprecated-declarations', '-Wno-gnu-alignof-expression']
cpp = ['ccache', '$NDK_BIN/aarch64-linux-android$SDK_VER-clang++', '-fomit-frame-pointer', '--start-no-unused-arguments', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '-fno-rtti', '--end-no-unused-arguments', '-Wno-error=c++11-narrowing', '-Wno-deprecated-declarations', '-Wno-gnu-alignof-expression']
c_ld = '$NDK_BIN/ld.lld'
cpp_ld = '$NDK_BIN/ld.lld'
strip = '$NDK_BIN/aarch64-linux-android-strip'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=NDKDIR/pkg-config', '/usr/bin/pkg-config']
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF
cd mesa && meson setup "$MESA_BUILD_DIR" \
    --cross-file "$WORK_DIR/$CROSS_FILE" \
    -Dbuildtype=release -Dplatforms=android \
    -Dplatform-sdk-version="$SDK_VER" \
    -Dandroid-stub=true -Dgallium-drivers= \
    -Dvulkan-drivers=freedreno -Dfreedreno-kmds=kgsl \
    -Db_lto=true -Db_lto_mode=default \
    -Db_ndebug=true -Degl=disabled \
    -Dstrip=true || exit

# compile
ninja -C "$MESA_BUILD_DIR" || exit

# create zip
cp "$MESA_BUILD_DIR/src/freedreno/vulkan/libvulkan_freedreno.so" vulkan.adreno.so || exit
cat <<EOF >"meta.json"
{
  "schemaVersion": 1,
  "name": "Freedreno Turnip Driver",
  "description": "$NDK_VER",
  "vendor": "Mesa3D",
  "author": "lizzie",
  "packageVersion": "3",
  "driverVersion": "Vulkan 1.4",
  "minApi": $SDK_VER,
  "libraryName": "vulkan.turnip.so"
}
EOF
tar -a -cf "mesa-turnip-$NDK_VER-$SDK_VER.tar.xz" vulkan.adreno.so meta.json || exit
tar -tvf "mesa-turnip-$NDK_VER-$SDK_VER.tar.xz" || exit
zip "mesa-turnip-$NDK_VER-$SDK_VER.zip" vulkan.adreno.so meta.json || exit
#rm vulkan.adreno.so meta.json
