#!/bin/bash
#set -x



launch_qemu() {

STAGE=$HOME/tla
TOP=$STAGE/teeny-linux
qemu-system-arm -M versatilepb  \
    -dtb $TOP/obj/linux-arm-versatile_defconfig/arch/arm/boot/dts/versatile-pb.dtb \
    -kernel $TOP/obj/linux-arm-versatile_defconfig/arch/arm/boot/zImage \
    -initrd $TOP/obj/initramfs.igz \
    -nographic -append "earlyprintk=serial,ttyS0 console=ttyAMA0"
}


make_kernel() {

cd $STAGE/linux-4.10.6
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- O=$TOP/obj/linux-arm-versatile_defconfig -j2

}


config_kernel_minimal () {

cd $STAGE/linux-4.10.6
mkdir -pv $TOP/obj/linux-arm-versatile_defconfig
cp arch/arm/configs/versatile_defconfig $TOP/obj/linux-arm-versatile_defconfig/.config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- O=$TOP/obj/linux-arm-versatile_defconfig olddefconfig

sed -i  's/# CONFIG_EARLY_PRINTK is not set/CONFIG_EARLY_PRINTK=y/'  $TOP/obj/linux-arm-versatile_defconfig/.config

}


create_initramfs() {

cd $TOP/initramfs/arm-busybox
find . | cpio -H newc -o > ../initramfs.cpio
cd ..
cat initramfs.cpio | gzip > $TOP/obj/initramfs.igz

}





create_init_file() {
cat << EOF >> $TOP/initramfs/arm-busybox/init
#!/bin/sh
 
mount -t proc none /proc
mount -t sysfs none /sys
mount -t debugfs none /sys/kernel/debug
 
echo -e "\nBoot took $(cut -d' ' -f1 /proc/uptime) seconds\n"
 
exec /bin/sh
EOF

chmod +x $TOP/initramfs/arm-busybox/init
}





build_initramfs() {

mkdir -pv $TOP/initramfs/arm-busybox
cd $TOP/initramfs/arm-busybox
mkdir -pv {bin,dev,sbin,etc,proc,sys/kernel/debug,usr/{bin,sbin},lib,lib64,mnt/root,root}
cp -av $TOP/obj/busybox-arm/_install/* $TOP/initramfs/arm-busybox
sudo cp -av /dev/{null,console,tty,sda1} $TOP/initramfs/arm-busybox/dev/

}



minimal_userland() {

cd $STAGE/busybox-*
mkdir -pv $TOP/obj/busybox-arm
make O=$TOP/obj/busybox-arm  ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig
if [ $? == "0" ];then
        echo "setting defconfig successfull"
	echo "Building busybox as static "
	sed -i  's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/'  $TOP/obj/busybox-arm/.config
	cd $TOP/obj/busybox-arm
	make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- install
else
        exit 1
fi

}


download_kernel_busybox ()
{
cd $STAGE

if [ -d $STAGE/linux-* ];then
    echo "Kernel dir exists , skipping kernel download"
else
curl https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.10.6.tar.xz | tar xJf -
fi

if [ -d $STAGE/busybox-* ];then
	echo " Busybox dir exists , skipping busybox download"
else
curl https://busybox.net/downloads/busybox-1.26.2.tar.bz2 | tar xjf -
fi
}


create_workarea() {

STAGE=~/tla
TOP=$STAGE/teeny-linux
mkdir -p $STAGE

}



install_arm_toolchain() {
 pass=$1
echo $pass |  sudo apt-get install curl libncurses5-dev qemu-system-arm gcc-arm-linux-gnueabi -y
if [ $? == "0" ];then
        echo " toolchain install successfull "
else
        echo " toolchain install failed "
fi

}


update_ubuntu(){
pass=$1
echo $pass | sudo -S apt-get update
if [ $? == "0" ];then
	echo " apt-get successful"
else
	echo " apt-get failed "
fi

}


#### Main function ##
echo "welcome to busybox qemu arm" 

echo " ####################"

echo " Before installing ubuntu arm toolchian , we need to run apt-get update" 
echo " Can we run apt-get update , To run apt-get and install toolchain Enter Yes/No"
read input 
case $input in
	yes)
		echo "Please enter password for apt-get update"
		read -s pass
		update_ubuntu $pass
		install_arm_toolchain $pass ;;
	no)
			echo "Not updating "
			exit 1
			;;
esac



echo "Now time to setup work area "

create_workarea

echo "Download kernel and bsybox"

download_kernel_busybox

echo "Create minimal userland  busybox "

minimal_userland

echo "creating initramfs structure "

build_initramfs


echo "Create init file and make it exectuble"

create_init_file

echo " Create Initramfs "

create_initramfs

echo "Config kerenl minimal "

config_kernel_minimal

echo " Make kernel "

make_kernel

echo " Launching qemu" 

launch_qemu 