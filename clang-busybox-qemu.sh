#!/bin/bash

set -x 
STAGE=~/tla
TOP=$STAGE/teeny-linux
tc_dir=$STAGE/tc_dir
helper_dir=$STAGE/helper_dir




launch_qemu() {

export PATH=$helper_dir/qemu-arm-binaries:$PATH
qemu-system-aarch64 -M virt -cpu cortex-a53  -kernel  \
     $TOP/obj/kernel-build/arch/arm64/boot/Image \
    -initrd $TOP/initramfs/initramfs.igz \
    -nographic -append "earlyprintk=serial,ttyS0 rdinit=/sbin/init"
}



config_kernel_minimal_compile() {
echo "                                       "
echo "========================================="


cd $STAGE/linux-*
mkdir -pv $TOP/obj/kernel-build/
cp $helper_dir/qemu-arm-binaries/defconfig $TOP/obj/kernel-build/.config

source $tc_dir/sdk/clang_sdk/environment-setup-cortexa57-poky-linux-musl
make -j10 ARCH=arm64 CROSS_COMPILE=aarch64-poky-linux-musl- CC="$CLANGCC" O=$TOP/obj/kernel-build olddefconfig

make -j10 ARCH=arm64 CROSS_COMPILE=aarch64-poky-linux-musl- CC="$CLANGCC" O=$TOP/obj/kernel-build 

}




create_initramfs() {
cd $TOP/initramfs/arm-busybox
find . | cpio -H newc -o > ../initramfs.cpio
cd ..
cat initramfs.cpio | gzip > initramfs.igz

}


create_init_file() {

cat << EOF >> $TOP/initramfs/arm-busybox/etc/inittab
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh
EOF
	
mkdir -p $TOP/initramfs/arm-busybox/etc/init.d
cat << EOF >> $TOP/initramfs/arm-busybox/etc/init.d/rcS
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
EOF

chmod +x $TOP/initramfs/arm-busybox/etc/init.d/rcS

}



build_initramfs() {

mkdir -pv $TOP/initramfs/arm-busybox
cd $TOP/initramfs/arm-busybox
mkdir -pv {bin,dev,sbin,etc,proc,sys/kernel/debug,usr/{bin,sbin},lib,lib64,mnt/root,root}
cp -av $TOP/obj/busybox-arm64/_install/* $TOP/initramfs/arm-busybox

}



minimal_userland(){

busybox_dir=`ls -d */ | grep busybox`
cd $STAGE/$busybox_dir
mkdir -pv $TOP/obj/busybox-arm64
cp $helper_dir/qemu-arm-binaries/busybox-yocto-clang.patch $STAGE/
cp $helper_dir/qemu-arm-binaries/0001-Turn-ptr_to_globals-and-bb_errno-to-be-non-const.patch $STAGE/
patch -p1 < ../busybox-yocto-clang.patch
patch -p1 < ../0001-Turn-ptr_to_globals-and-bb_errno-to-be-non-const.patch

source $tc_dir/sdk/clang_sdk/environment-setup-cortexa57-poky-linux-musl

make O=$TOP/obj/busybox-arm64  ARCH=arm64 CROSS_COMPILE=aarch64-poky-linux-musl- CC="$CLANGCC" defconfig

sed -i  's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/'  $TOP/obj/busybox-arm64/.config

cd $TOP/obj/busybox-arm64

make -j2 ARCH=arm64 CROSS_COMPILE=aarch64-poky-linux-musl- CC="$CLANGCC"

make ARCH=arm64 CROSS_COMPILE=aarch64-poky-linux-musl-  CC="$CLANGCC" install

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

install_tc()
{
  cd $tc_dir
  cp $helper_dir/qemu-arm-binaries/clang-musl-sdk.tar.gz .
  tar xf clang-musl-sdk.tar.gz
  cd sdk
  cp $helper_dir/qemu-arm-binaries/install-poky-tc-clang .
  ./install-poky-tc-clang

}


download_helper_artifacts ()
{
        cd $helper_dir
        git clone https://github.com/Anand1985-gl/qemu-arm-binaries.git
}

create_workarea() {

echo "                                       "
echo "========================================="

if [ -d $HOME/tla ];then
        echo -e "tla directory already exists, deleting old one ??  Enter yes/no \n"
        read input
        input1=`echo "${input,,}"`
        case $input1 in
                yes)
                        rm -rf $HOME/tla
                        mkdir -p $STAGE
                        mkdir -p $tc_dir
                        mkdir -p $TOP
                        mkdir -p $helper_dir
                        ;;
                no)
                        echo -e "Not deleting tla \n "
                        ;;
                *)
                        echo " unknow option , exiting !!!"
                        exit 1
        esac
else
        mkdir -p $STAGE
        mkdir -p $tc_dir
        mkdir -p $TOP
        mkdir -p $helper_dir

fi

}



#### Main function ##
echo -e  "welcome to Clang  busybox qemu arm64  \n" 2>&1 | tee -a $HOME/full-log

echo -e "##################### \n" 2>&1 | tee -a  $HOME/full-log

echo -e "Now time to setup work area \n" 2>&1 | tee -a $HOME/full-log

create_workarea

echo -e "Download Clang toolcahin and helper artifacts  \n"

download_helper_artifacts

echo -e "Install Clang toolchain  \n"

install_tc

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

echo -e "Config kerenl minimal and compile  \n"  2>&1 | tee -a $HOME/full-log

config_kernel_minimal_compile

echo -e "Launching qemu \n "  2>&1 | tee -a $HOME/full-log

launch_qemu

