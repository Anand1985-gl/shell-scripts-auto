#!/bin/bash
#set -x


CLFS=~/clfs
SOURCES=$CLFS/sources


run_qemu(){

	echo -e " running qemu \n"   2>&1 | tee -a $HOME/full-log
	source $HOME/clfs/clfs-env
	$HOME/clfs/qemu-arm-binaries/qemu-system-aarch64 -M virt -cpu cortex-a53  -kernel $HOME/clfs/sources/linux-5.4/arch/arm64/boot/Image -initrd $HOME/clfs/initramfs.igz -nographic -append "earlyprintk=serial,ttyS0 rdinit=/sbin/init"


}

prepare_init_and_ramfs() {
	echo -e " Preparing Init \n"   2>&1 | tee -a $HOME/full-log
        source $HOME/clfs/clfs-env	
	cd $HOME/clfs/
cat << EOF >> $HOME/clfs/targetfs/etc/inittab
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh
EOF

	mkdir -p $HOME/clfs/targetfs/etc/init.d
cat << EOF >> $HOME/clfs/targetfs/etc/init.d/rcS
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
EOF

	chmod +x $HOME/clfs/targetfs/etc/init.d/rcS

	cd $HOME/clfs/targetfs
	find . | cpio -H newc -o > ../initramfs.cpio
	cd ..
	cat initramfs.cpio | gzip > initramfs.igz
}



linux_compile() {
	 echo -e " linux compile \n"  2>&1 | tee -a $HOME/full-log
         source $HOME/clfs/clfs-env
	 cd $CLFS/sources

	 rm -rf linux-5.4
	 tar xf linux-5.4.tar.xz
	 cd linux-5.4
	 make mrproper

	 cp $CLFS/qemu-arm-binaries/defconfig $CLFS/sources/linux-5.4/.config
	 make ARCH=${CLFS_ARCH} CROSS_COMPILE=${CLFS_TARGET}- olddefconfig
	 make ARCH=${CLFS_ARCH} CROSS_COMPILE=${CLFS_TARGET}- 

	 make ARCH=${CLFS_ARCH} CROSS_COMPILE=${CLFS_TARGET}- \
    		INSTALL_MOD_PATH=${CLFS}/targetfs modules_install

}


helper_scripts() {

	echo -e " downloading helper scripts \n"   2>&1 | tee -a $HOME/full-log
	source $HOME/clfs/clfs-env
   	cd $CLFS/
	git clone https://github.com/Anand1985-gl/qemu-arm-binaries
}	

busybox_install() {
   echo -e " busybox install \n"   2>&1 | tee -a $HOME/full-log
   source $HOME/clfs/clfs-env
   cd $CLFS/sources

   tar xf busybox-1.31.1.tar.bz2
   cd busybox-1.31.1
   make distclean

   make ARCH="${CLFS_ARCH}" defconfig
   sed -i 's/\(CONFIG_\)\(.*\)\(INETD\)\(.*\)=y/# \1\2\3\4 is not set/g' .config
   sed -i 's/\(CONFIG_IFPLUGD\)=y/# \1 is not set/' .config

   sed -i 's/\(CONFIG_FEATURE_WTMP\)=y/# \1 is not set/' .config
   sed -i 's/\(CONFIG_FEATURE_UTMP\)=y/# \1 is not set/' .config

   sed -i 's/\(CONFIG_UDPSVD\)=y/# \1 is not set/' .config
   sed -i 's/\(CONFIG_TCPSVD\)=y/# \1 is not set/' .config

   make ARCH="${CLFS_ARCH}" CROSS_COMPILE="${CLFS_TARGET}-"

   make ARCH="${CLFS_ARCH}" CROSS_COMPILE="${CLFS_TARGET}-"\
  CONFIG_PREFIX="${CLFS}/targetfs" install

   cp -v examples/depmod.pl ${CLFS}/cross-tools/bin
   chmod -v 755 ${CLFS}/cross-tools/bin/depmod.pl

}	


musl_shared() {
  
   echo -e " install musl shared   \n"  2>&1 | tee -a $HOME/full-log
   source $HOME/clfs/clfs-env
   cd $CLFS/sources
   rm -rf musl-1.2.0
   tar xf musl-1.2.0.tar.gz
   cd musl-1.2.0
   ./configure \
  CROSS_COMPILE=${CLFS_TARGET}- \
  --prefix=/ \
  --disable-static \
  --target=${CLFS_TARGET}
   make
  DESTDIR=${CLFS}/targetfs make install-libs

}

install_libgcc() {

  echo -e " install libgcc  \n"	  2>&1 | tee -a $HOME/full-log
  source $HOME/clfs/clfs-env
  cp -v ${CLFS}/cross-tools/${CLFS_TARGET}/lib64/libgcc_s.so.1 ${CLFS}/targetfs/lib/
  ${CLFS_TARGET}-strip ${CLFS}/targetfs/lib/libgcc_s.so.1

}


target_system() {
  
   echo -e "preparing target system  \n"  2>&1 | tee -a $HOME/full-log
   source $HOME/clfs/clfs-env
   mkdir -pv ${CLFS}/targetfs
   echo export CC=\""${CLFS_TARGET}-gcc --sysroot=${CLFS}/targetfs\"" >> $HOME/clfs/clfs-env
   echo export CXX=\""${CLFS_TARGET}-g++ --sysroot=${CLFS}/targetfs\"" >> $HOME/clfs/clfs-env
   echo export AR=\""${CLFS_TARGET}-ar\"" >> $HOME/clfs/clfs-env
   echo export AS=\""${CLFS_TARGET}-as\"" >> $HOME/clfs/clfs-env
   echo export LD=\""${CLFS_TARGET}-ld --sysroot=${CLFS}/targetfs\"" >> $HOME/clfs/clfs-env
   echo export RANLIB=\""${CLFS_TARGET}-ranlib\"" >> $HOME/clfs/clfs-env
   echo export READELF=\""${CLFS_TARGET}-readelf\"" >> $HOME/clfs/clfs-env
   echo export STRIP=\""${CLFS_TARGET}-strip\"" >> $HOME/clfs/clfs-env
   
   source $HOME/clfs/clfs-env
	
   mkdir -pv ${CLFS}/targetfs/{bin,boot,dev,etc,home,lib/{firmware,modules}}
   mkdir -pv ${CLFS}/targetfs/{mnt,opt,proc,sbin,srv,sys}
   mkdir -pv ${CLFS}/targetfs/var/{cache,lib,local,lock,log,opt,run,spool}
   install -dv -m 0750 ${CLFS}/targetfs/root
   install -dv -m 1777 ${CLFS}/targetfs/{var/,}tmp
   mkdir -pv ${CLFS}/targetfs/usr/{,local/}{bin,include,lib,sbin,share,src}

 }



gcc_final(){
  echo -e "final gcc  \n"   2>&1 | tee -a $HOME/full-log
  source $HOME/clfs/clfs-env
  cd $CLFS/sources

  rm -rf gcc-build gcc-9.3.0

  tar xf mpfr-4.0.2.tar.xz
  mv -v mpfr-4.0.2 mpfr
  tar xf mpc-1.1.0.tar.gz
  mv -v mpc-1.1.0 mpc
  tar xf gmp-6.2.0.tar.bz2
  mv -v gmp-6.2.0 gmp

  tar xf gcc-9.3.0.tar.xz
  mv mpfr gcc-9.3.0
  mv mpc gcc-9.3.0
  mv gmp gcc-9.3.0

  mkdir -v gcc-build
  cd gcc-build

  ../gcc-9.3.0/configure \
  --prefix=${CLFS}/cross-tools \
  --build=${CLFS_HOST} \
  --host=${CLFS_HOST} \
  --target=${CLFS_TARGET} \
  --with-sysroot=${CLFS}/cross-tools/${CLFS_TARGET} \
  --disable-nls \
  --enable-languages=c \
  --enable-c99 \
  --enable-long-long \
  --disable-libmudflap \
  --disable-libsanitizer \
  --disable-multilib \
  --with-mpfr-include=$(pwd)/../gcc-9.3.0/mpfr/src \
  --with-mpfr-lib=$(pwd)/mpfr/src/.libs \
  --with-arch=${CLFS_ARM_ARCH} \

  make
  make install 

}



musl_install_1() {

	echo -e "installing musl \n"  2>&1 | tee -a $HOME/full-log
	source $HOME/clfs/clfs-env
	cd $CLFS/sources
	tar xf musl-1.2.0.tar.gz
	cd musl-1.2.0
	./configure \
  	CROSS_COMPILE=${CLFS_TARGET}- \
  	--prefix=/ \
  	--target=${CLFS_TARGET}
	make
	DESTDIR=${CLFS}/cross-tools/${CLFS_TARGET} make install

}


gcc_stage_1() {
 echo -e "installing gcc stage 1  \n"  2>&1 | tee -a $HOME/full-log
 source $HOME/clfs/clfs-env
 cd $CLFS/sources
 
 tar xf mpfr-4.0.2.tar.xz
 mv -v mpfr-4.0.2 mpfr
 tar xf mpc-1.1.0.tar.gz
 mv -v mpc-1.1.0 mpc
 tar xf gmp-6.2.0.tar.bz2
 mv -v gmp-6.2.0 gmp

 tar xf gcc-9.3.0.tar.xz
 mv mpfr gcc-9.3.0
 mv mpc gcc-9.3.0
 mv gmp gcc-9.3.0

 mkdir -v gcc-build
 cd gcc-build
 ../gcc-9.3.0/configure \
  --prefix=${CLFS}/cross-tools \
  --build=${CLFS_HOST} \
  --host=${CLFS_HOST} \
  --target=${CLFS_TARGET} \
  --with-sysroot=${CLFS}/cross-tools/${CLFS_TARGET} \
  --disable-nls \
  --disable-shared \
  --without-headers \
  --with-newlib \
  --disable-decimal-float \
  --disable-libgomp \
  --disable-libmudflap \
  --disable-libsanitizer \
  --disable-libssp \
  --disable-libatomic \
  --disable-libquadmath \
  --disable-threads \
  --enable-languages=c \
  --disable-multilib \
  --with-mpfr-include=$(pwd)/../gcc-9.3.0/mpfr/src \
  --with-mpfr-lib=$(pwd)/mpfr/src/.libs \
  --with-arch=${CLFS_ARM_ARCH} \
   
   make all-gcc all-target-libgcc
   make install-gcc install-target-libgcc
}	


cross_binutils() {
	echo -e "installing cross binutils  \n"  2>&1 | tee -a $HOME/full-log
	source $HOME/clfs/clfs-env
	cd $CLFS/sources
	tar xf binutils-2.34.tar.bz2
	cd binutils-2.34
	mkdir -v ../binutils-build
	cd ../binutils-build
	../binutils-2.34/configure \
   --prefix=${CLFS}/cross-tools \
   --target=${CLFS_TARGET} \
   --with-sysroot=${CLFS}/cross-tools/${CLFS_TARGET} \
   --disable-nls \
   --disable-multilib
       make configure-host
       make 
       make install       
}



linux_headers(){
	echo -e "installing linux headers  \n" 2>&1 | tee -a $HOME/full-log
	source $HOME/clfs/clfs-env
	cd $CLFS/sources
	tar xf linux-5.4.tar.xz
	cd linux-5.4
	make mrproper
	make ARCH=${CLFS_ARCH} headers_check
	make ARCH=${CLFS_ARCH} INSTALL_HDR_PATH=${CLFS}/cross-tools/${CLFS_TARGET} headers_install
}


download_sources () {
echo -e "want to download sources ??   Enter yes/no \n"  2>&1 | tee -a $HOME/full-log
read input
input1=`echo "${input,,}"`
case $input1 in
          yes)
                  cd $CLFS/sources
		  wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.4.tar.xz
		  wget https://ftp.gnu.org/gnu/binutils/binutils-2.34.tar.bz2
		  wget https://ftp.gnu.org/gnu/gcc/gcc-9.3.0/gcc-9.3.0.tar.xz 
		  wget https://ftp.gnu.org/gnu/mpfr/mpfr-4.0.2.tar.xz
		  wget https://ftp.gnu.org/pub/gnu/mpc/mpc-1.1.0.tar.gz
		  wget https://ftp.gnu.org/gnu/gmp/gmp-6.2.0.tar.bz2
		  wget https://www.musl-libc.org/releases/musl-1.2.0.tar.gz
		  wget https://www.busybox.net/downloads/busybox-1.31.1.tar.bz2
		  ;;
          no)
                        echo -e "Skipping download source  \n "
                        ;;
          *)
                        echo " unknow option , exiting !!!"
                        exit 1
esac

}	


create_crosstools_area (){

source $HOME/clfs/clfs-env
mkdir -p ${CLFS}/cross-tools/${CLFS_TARGET}
cd ${CLFS}/cross-tools/${CLFS_TARGET}
ln -sfv . ${CLFS}/cross-tools/${CLFS_TARGET}/usr

}


create_workarea() {

echo "                                       "
echo "========================================="

if [ -d $HOME/clfs ];then
        echo -e "clfs directory already exists, deleting old one ??  Enter yes/no \n" 2>&1 | tee -a $HOME/full-log
        read input
        input1=`echo "${input,,}"`
        case $input1 in
                yes)
                        rm -rf $HOME/clfs
			mkdir -p $CLFS
        		mkdir -p $SOURCES
        		chmod 777 ${CLFS}
                        ;;
                no)
                        echo -e "Not deleting clfs dir \n "
                        ;;
                *)
                        echo " unknow option , exiting !!!"
                        exit 1
        esac
else        
        mkdir -p $CLFS
        mkdir -p $SOURCES
	chmod 777 ${CLFS}

fi
}

create_env (){
cat << EOF >> $HOME/clfs/clfs-env
umask 022
CLFS=$HOME/clfs
LC_ALL=POSIX
PATH=${CLFS}/cross-tools/bin:/bin:/usr/bin
export CLFS LC_ALL PATH
unset CFLAGS
export CLFS_HOST="x86_64-cross-linux-gnu"
export CLFS_TARGET="aarch64-linux-musl"
export CLFS_ARCH="arm64"
export CLFS_ARM_ARCH="armv8-a"
EOF

}


#### Main function ##
echo -e  "Welcome to CLFS qemu \n" 2>&1 | tee -a $HOME/full-log

echo -e "Now time to setup work area \n" 2>&1 | tee -a $HOME/full-log

start=`date +%s`

create_workarea

create_env

create_crosstools_area

download_sources

linux_headers

cross_binutils

gcc_stage_1

musl_install_1

gcc_final

target_system

install_libgcc

musl_shared

busybox_install

helper_scripts

linux_compile

prepare_init_and_ramfs

end=`date +%s`

runtime=$((end-start))
echo -e "Total time taken =`echo  "scale=2;$runtime/60" |  bc -l` mins \n"  2>&1 | tee -a $HOME/full-log

run_qemu


