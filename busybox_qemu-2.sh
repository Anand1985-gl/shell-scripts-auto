#!/bin/bash
set -x
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
export PATH=$helper_dir/qemu-arm-binaries:$PATH
qemu-system-aarch64 -M virt -cpu cortex-a53  -kernel  \
     $TOP/obj/kernel-build/arch/arm64/boot/Image \
    -initrd $TOP/obj/initramfs.igz \
    -nographic -append "earlyprintk=serial,ttyS0 console=ttyAMA0"
}


make_kernel() {


start=`date +%s`

cd $STAGE/linux-*
export PATH=$tc_dir/$toolchain_path/bin:$PATH
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=$TOP/obj/kernel-build -j2

end=`date +%s`
runtime=$((end-start))
echo -e "time taken to compile kernel =`echo  "scale=2;$runtime/60" |  bc -l` mins \n"  2>&1 | tee -a $HOME/full-log

}


config_kernel_minimal () {

echo "                                       "
echo "========================================="


cd $STAGE/linux-*
mkdir -pv $TOP/obj/kernel-build/
cp $helper_dir/qemu-arm-binaries/defconfig $TOP//obj/kernel-build/.config 
export PATH=$tc_dir/$toolchain_path/bin:$PATH
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=$TOP/obj/kernel-build olddefconfig

#sed -i  's/# CONFIG_EARLY_PRINTK is not set/CONFIG_EARLY_PRINTK=y/'  $TOP/obj/linux-arm-versatile_defconfig/.config

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
#sudo cp -av /dev/{null,console,tty} $TOP/initramfs/arm-busybox/dev/

}



minimal_userland() {

echo "                                       "
echo "========================================="


cd $STAGE/busybox-*
mkdir -pv $TOP/obj/busybox-arm
export PATH=$tc_dir/$toolchain_path/bin:$PATH


make O=$TOP/obj/busybox-arm  ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig

if [ $? == "0" ];then
	start=`date +%s`
	echo "setting defconfig successfull"
	echo -e "Building busybox as static \n " 2>&1 | tee -a $HOME/full-log
	sed -i  's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/'  $TOP/obj/busybox-arm/.config
	cd $TOP/obj/busybox-arm
	export PATH=$tc_dir/$toolchain_path/bin:$PATH
	make -j2 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
	make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install
	end=`date +%s`

	runtime=$((end-start))

	echo -e "time taken to build userland =`echo  "scale=2;$runtime/60" |  bc -l` mins \n"  2>&1 | tee -a $HOME/full-log

else
        exit 1
fi

}


download_kernel_latest ()
{
	cd $STAGE

        echo -e "kernel download......"
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

}

download_busybox_latest ()
{
	cd $STAGE 
	echo -e "busybox download ...... \n "
	start=`date +%s`
	echo -e "Getting latest stable busybox \n" 2>&1 | tee -a $HOME/full-log
	wget https://www.busybox.net/
	mv index.html index-busybox.html
	x=`cat index-busybox.html | nl -b a |  grep "\-\- BusyBox" |  grep \(stable\) | head -1 | cut -d '<' -f1 | sed 's/[^0-9]//g'`
	echo $x
	ll=`expr $x + 1`
        echo $ll
	
	link_line_busybox=`cat index-busybox.html | sed -n "$ll"p | cut -d '"' -f2`
        echo $link_line_busybox

	curl $link_line_busybox | tar xjf -
	end=`date +%s`
        runtime=$((end-start))
        echo -e "time taken to download and extract busybox=`echo  "scale=2;$runtime/60" |  bc -l` mins \n" 2>&1 | tee -a $HOME/full-log
}

download_helper_artifacts ()
{
	cd $helper_dir
	git clone https://github.com/Anand1985-gl/qemu-arm-binaries.git 

}


download_linaro ()
{
        echo -e "Downloading linaro toolchain \n"
	cd $tc_dir
	pwd
	wget https://releases.linaro.org/components/toolchain/binaries/latest-7/aarch64-linux-gnu/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu.tar.xz
	if [ $? == "0" ];then
        	echo -e "toolchain downlaod succesfull \n"
		echo -e "extracting toolchain \n"
	        tar xf  gcc-linaro*	
	else
        	echo " toolchain install failed "
	fi
	toolchain_path=`ls -l | grep ^d | awk '{print $9}'`


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
			;;
        	no)
                        echo -e "Not deleting tla \n "
                        ;;
        	*)
                	echo " unknow option , exiting !!!"
                	exit 1
	esac
	STAGE=~/tla
	TOP=$STAGE/teeny-linux
	tc_dir=$STAGE/tc_dir
	helper_dir=$STAGE/helper_dir
	mkdir -p $STAGE
	mkdir -p $tc_dir
	mkdir -p $TOP
	mkdir -p $helper_dir

fi

}

#### Main function ##
echo -e  "Welcome to busybox qemu arm \n" 2>&1 | tee -a $HOME/full-log 

echo -e "Now time to setup work area \n" 2>&1 | tee -a $HOME/full-log

create_workarea

while [ -n "$1" ]
do
        case "$1" in
                --toolchain) echo -e "Found toolcahin option \n"
                        param="$2"
                        if [ $param == "linaro" ]
                        then
                                download_linaro
                        elif [ $param == "yocto" ]
                        then
                                download_yocto
                        else
                                echo "give proper toolcahin"
                                exit 1
                        fi
                        shift 2;;


                --busybox)      echo -e "Busybox option \n"
			param="$2"
                        if [ $param == "1.33.0" ]
                        then
                                cd $STAGE
				wget https://www.busybox.net/downloads/busybox-1.33.0.tar.bz2
				tar xf busybox-1.33.0.tar.bz2
				rm busybox-1.33.0.tar.bz2
                        elif [ $param == "1.32.1" ]
			then
                                cd $STAGE
				wget https://www.busybox.net/downloads/busybox-1.32.1.tar.bz2
				tar xf busybox-1.32.1.tar.bz2
				rm busybox-1.32.1.tar.bz2
			else
                                echo -e "Downloading latest busybox \n"
				download_busybox_latest
                        fi
                        shift 2;;

                --kernel) echo -e "Kernel option \n"
			param="$2"
			if [ $param == "5.4.19" ]
                        then
                                cd $STAGE
                                wget https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.4.19.tar.xz
				tar xf linux-5.4.19.tar.xz
				rm -rf linux-5.4.19.tar.xz
                        elif [ $param == "5.9" ]
                        then
                                cd $STAGE
                                wget https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.9.tar.xz
				tar xf linux-5.9.tar.xz
				rm -rf linux-5.9.tar.xz
                        else
                                echo -e "Downloading latest Kernel \n"
                                download_kernel_latest
                        fi
                        shift 2;;

                --)shift
                   break;;
                *)echo "$1 is not option"
                esac
                shift
done

echo -e "Download helper artifacts \n"
download_helper_artifacts 

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
