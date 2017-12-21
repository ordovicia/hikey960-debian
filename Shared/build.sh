#!/bin/bash

set -ex

cd

export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64

download_linux() { (
    cd Downloads

    wget https://github.com/96boards-hikey/linux/archive/working-hikey960-v4.14-rc7-2017-11-03.tar.gz
    tar xzvf working-hikey960-v4.14-rc7-2017-11-03.tar.gz > /dev/null
    mv linux-working-hikey960-v4.14-rc7-2017-11-03 ../Build/linux-hikey960
) }

build_linux() { (
    cd Build/linux-hikey960

    make defconfig
    make -j4

    cp arch/$ARCH/boot/Image ..
    cp arch/$ARCH/boot/dts/hisilicon/hi3660-hikey960.dtb ..

    make clean
) }

download_rootfs() { (
    cd Downloads

    wget https://releases.linaro.org/debian/images/developer-arm64/latest/linaro-stretch-developer-20171109-88.tar.gz
    sudo tar xzvf linaro-stretch-developer-20171109-88.tar.gz > /dev/null
    sudo mv binary ../Build/rootfs
) }

build_grub() { (
    cd Build

    git clone https://git.savannah.gnu.org/git/grub.git --depth 1
    cd grub
    ./autogen.sh
    ./configure --prefix=/usr --target=aarch64-linux-gnu --with-platform=efi
    make -j2
    mkdir -p ../grub-install
    make DESTDIR=$PWD/../grub-install install
) }

download_uefi() { (
    cd Downloads

    wget https://builds.96boards.org/releases/hikey/linaro/debian/latest/boot-fat.uefi.img.gz
    gzip -d boot-fat.uefi.img.gz
    mv boot-fat.uefi.img ../Build/
) }

install_grub_uefi() { (
    cd Build

    cat > grub.config << 'EOF'
search.fs_label rootfs root
set prefix=($root)/boot/grub
configfile $prefix/grub.cfg
EOF

    GRUB_MODULES="boot chain configfile echo efinet eval ext2 fat font gettext gfxterm \
gzio help linux loadenv lsefi normal part_gpt part_msdos read regexp search \
search_fs_file search_fs_uuid search_label terminal terminfo test tftp time halt reboot"
    grub-install/usr/bin/grub-mkimage \
        --config grub.config \
        --dtb hi3660-hikey960.dtb \
        --directory=$PWD/grub-install/usr/lib/grub/arm64-efi \
        --output=grubaa64.efi \
        --format=arm64-efi \
        --prefix="/boot/grub" \
        $GRUB_MODULES

    sudo mount -o loop boot-fat.uefi.img loop
    sudo cp grubaa64.efi loop/EFI/BOOT
    sudo umount loop
) }

download_wifi_firmware() { (
    cd Downloads

    git clone git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git --depth 1
    cp linux-firmware/ti-connectivity/wl18xx-fw-4.bin ../Build
) }

arrange_rootfs() { (
    cd Build

    # Image
    sudo cp Image rootfs/boot/
    sudo cp hi3660-hikey960.dtb rootfs/boot/

    # Modules
    (
        cd linux-hikey960
        sudo make INSTALL_MOD_PATH=$PWD/../rootfs modules_install
    )

    # Wi-Fi firmware
    sudo mkdir -p rootfs/lib/firmware/ti-connectivity
    sudo cp wl18xx-fw-4.bin rootfs/lib/firmware/ti-connectivity/

    # grub.cfg
    sudo mkdir -p rootfs/boot/grub
    cat > grub.cfg << 'EOF'
set default="0"
set timeout=30

menuentry 'Debian GNU/Linux' {
    search.fs_label rootfs root
    set root=($root)

    echo 'Loading linux-hikey960 v4.14-rc7 ...'
    linux /boot/Image console=tty0 console=ttyAMA6,115200n8 root=/dev/sdd10 rootwait rw efi=noruntime

    echo 'Loading devicetree ...'
    devicetree /boot/hi3660-hikey960.dtb
}

menuentry 'Fastboot' {
    search.fs_label boot boot_part
    chainloader ($boot_part)/EFI/BOOT/fastboot.efi
}
EOF
    sudo mv grub.cfg rootfs/boot/grub/
) }

create_sparce_rootfs_image() { (
    cd Build

    dd if=/dev/zero of=rootfs.img bs=1M count=4096
    mkfs.ext4 -F -L rootfs rootfs.img
    sudo mount -o loop rootfs.img loop

    (
        cd rootfs
        sudo tar -cf - * | ( cd ../loop; sudo tar -xf - )
    )

    sudo umount loop
    img2simg rootfs.img rootfs.sparse.img 4096
) }

flash() { (
    cd Build

    # sudo fastboot flash boot boot-fat.uefi.img
    # sudo fastboot flash system rootfs.sparse.img

    echo "Please flash boot-fat.uefi.img and rootfs.sparse.img manually"
    date=$(date "+%Y%m%d-%H%M%S")
    cp boot-fat.uefi.img ~/Shared/boot-fat-$date.uefi.img
    cp rootfs.sparse.img ~/Shared/rootfs-$date.sparse.img
) }

mkdir -p Downloads Build/loop
download_linux
build_linux
download_rootfs
download_uefi
build_grub
install_grub_uefi
download_wifi_firmware
arrange_rootfs
create_sparce_rootfs_image
flash
