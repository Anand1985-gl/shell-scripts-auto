#!/bin/bash
#set -x
# 
# linux-5.9
# busybox-1.31.1
#
#


launch_qemu() {

echo "                                       "
echo "========================================="

STAGE=$HOME/tla
TOP=$STAGE/teeny-linux
qemu-system-arm -M versatilepb  \
    -dtb $TOP/obj/linux-arm-versatile_defconfig/arch/arm/boot/dts/versatile-pb.dtb \
    -kernel $TOP/obj/linux-arm-versatile_defconfig/arch/arm/boot/zImage \
    -initrd $TOP/obj/initramfs.igz \
    -nographic -append "earlyprintk=serial,ttyS0 console=ttyAMA0"
}


make_kernel() {


start=`date +%s`

cd $STAGE/linux-*
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- O=$TOP/obj/linux-arm-versatile_defconfig -j2

end=`date +%s`
runtime=$((end-start))
echo -e "time taken to compile kernel =`echo  "scale=2;$runtime/60" |  bc -l` mins \n"  2>&1 | tee -a $HOME/full-log

}


config_kernel_minimal () {

echo "                                       "
echo "========================================="


cd $STAGE/linux-*
mkdir -pv $TOP/obj/linux-arm-versatile_defconfig
cp arch/arm/configs/versatile_defconfig $TOP/obj/linux-arm-versatile_defconfig/.config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- O=$TOP/obj/linux-arm-versatile_defconfig olddefconfig

sed -i  's/# CONFIG_EARLY_PRINTK is not set/CONFIG_EARLY_PRINTK=y/'  $TOP/obj/linux-arm-versatile_defconfig/.config

}


create_initramfs() {

echo "                                       "
echo "========================================="


cd $TOP/initramfs/arm-busybox
find . | cpio -H newc -o > ../initramfs.cpio
cd ..
cat initramfs.cpio | gzip > $TOP/obj/initramfs.igz

}





create_init_file() {

echo "                                       "
echo "========================================="


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
echo "                                       "
echo "========================================="


mkdir -pv $TOP/initramfs/arm-busybox
cd $TOP/initramfs/arm-busybox
mkdir -pv {bin,dev,sbin,etc,proc,sys/kernel/debug,usr/{bin,sbin},lib,lib64,mnt/root,root}
cp -av $TOP/obj/busybox-arm/_install/* $TOP/initramfs/arm-busybox
sudo cp -av /dev/{null,console,tty} $TOP/initramfs/arm-busybox/dev/

}



minimal_userland() {

echo "                                       "
echo "========================================="


cd $STAGE/busybox-*
mkdir -pv $TOP/obj/busybox-arm
make O=$TOP/obj/busybox-arm  ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig
if [ $? == "0" ];then
	start=`date +%s`
	echo "setting defconfig successfull"
	echo -e "Building busybox as static \n " 2>&1 | tee -a $HOME/full-log
	sed -i  's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/'  $TOP/obj/busybox-arm/.config
	cd $TOP/obj/busybox-arm
	make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- install
	end=`date +%s`

	runtime=$((end-start))

	echo -e "time taken to build userland =`echo  "scale=2;$runtime/60" |  bc -l` mins \n"  2>&1 | tee -a $HOME/full-log

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
	start=`date +%s`
	echo -e "getting latest Stable kernel \n" 2>&1 | tee -a $HOME/full-log
	wget https://www.kernel.org/
	mv index.html index-kernel.html
	x=`cat index-kernel.html | nl -b a | grep "latest_link" | sed 's/[^0-9]//g'`
	echo $x 
	ll=`expr $x + 1`
	echo $ll

	link_line_kernel=`cat index-kernel.html | sed -n "$ll"p | cut -d '"' -f2`
	echo $link_line_kernel

	curl $link_line_kernel  | tar xJf -
	end=`date +%s`
	runtime=$((end-start))
	echo -e "time taken to download and extract Kernel=`echo  "scale=2;$runtime/60" |  bc -l` mins \n" 2>&1 | tee -a $HOME/full-log
fi

if [ -d $STAGE/busybox-* ];then
	echo " Busybox dir exists , skipping busybox download"
else
	start=`date +%s`
	echo -e "Getting latest stable busybox \n" 2>&1 | tee -a $HOME/full-log
	wget https://www.busybox.net/
	x=`cat index.html | nl -b a |  grep "\-\- BusyBox" |  grep \(stable\) | head -1 | cut -d '<' -f1 | sed 's/[^0-9]//g'`
	echo $x
	ll=`expr $x + 1`
        echo $ll
	
	link_line_busybox=`cat index.html | sed -n "$ll"p | cut -d '"' -f2`
        echo $link_line_busybox

	curl $link_line_busybox | tar xjf -
	end=`date +%s`
        runtime=$((end-start))
        echo -e "time taken to download and extract busybox=`echo  "scale=2;$runtime/60" |  bc -l` mins \n" 2>&1 | tee -a $HOME/full-log
fi
}


create_workarea() {

echo "                                       "
echo "========================================="

if [ -d $HOME/tla ];then
	echo " tla directory already exists, deleting old  \n"
	rm -rf $HOME/tla
	STAGE=~/tla
	TOP=$STAGE/teeny-linux
	mkdir -p $STAGE
else
	STAGE=~/tla
        TOP=$STAGE/teeny-linux
        mkdir -p $STAGE

fi

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
echo -e  "welcome to busybox qemu arm \n" 2>&1 | tee -a $HOME/full-log 

echo -e "##################### \n" 2>&1 | tee -a  $HOME/full-log 

echo "Before installing ubuntu arm toolchian , we need to run apt-get update " 2>&1 | tee -a $HOME/full-log
echo -e  "To run apt-get and install ubuntu arm  toolchain Enter Yes or No \n" 2>&1 | tee -a $HOME/full-log


read input
input1=`echo "${input,,}"`

case $input1 in
	yes)
		echo "Please enter password for apt-get update"
		read -s pass
		update_ubuntu $pass
		install_arm_toolchain $pass ;;
	no)
			echo "You said no , exiting  "
			exit 1
			;;
	*)
		echo " unknow option , exiting !!!"
		exit 1
esac



echo -e "Now time to setup work area \n" 2>&1 | tee -a $HOME/full-log

create_workarea

echo -e "Download kernel and busybox \n"  2>&1 | tee -a $HOME/full-log 

download_kernel_busybox

echo -e "Create minimal userland  busybox \n"  2>&1 | tee -a $HOME/full-log 

minimal_userland

echo -e "creating initramfs structure \n"  2>&1 | tee -a $HOME/full-log 

build_initramfs


echo -e "Create init file and make it exectuble \n"   2>&1 | tee -a $HOME/full-log 

create_init_file

echo -e "Create Initramfs \n"  2>&1 | tee -a $HOME/full-log 

create_initramfs

echo -e "Config kerenl minimal \n"  2>&1 | tee -a $HOME/full-log 

config_kernel_minimal

echo -e "Compiling kernel \n"  2>&1 | tee -a $HOME/full-log 

make_kernel

echo -e "Launching qemu \n "  2>&1 | tee -a $HOME/full-log 

launch_qemu 
