ROOT_PROJ = /mnt/coreos
TOOLCHAIN_ROOT := $(ROOT_PROJ)/tools
TARGET := $(shell uname -m)-coreos-linux-gnu

# Build directories
BINUTILS_BUILD_DIR := binutils-gdb/build
GCC_BUILD_DIR := gcc/build
GLIBC_BUILD_DIR := glibc/build

# Tasks need to be executed in the right order
all: prep build_binutils_p1 build_gcc_p1 linux-headers build_glibc build_libstdc build_m4 build_ncurses build_bash build_coreutils build_diffutils build_file

#We initialize the build environment here
prep:
	mkdir -pv $(ROOT_PROJ)
	mkdir -pv $(TOOLCHAIN_ROOT)
	mkdir -pv $(ROOT_PROJ)/etc
	mkdir -pv $(ROOT_PROJ)/var
	mkdir -pv $(ROOT_PROJ)/bin
	mkdir -pv $(ROOT_PROJ)/sbin
	mkdir -pv $(ROOT_PROJ)/lib
	mkdir -pv $(ROOT_PROJ)/usr/bin
	if [ `uname -m` = 'x86_64' ]; then mkdir -pv $(ROOT_PROJ)/lib64; fi

# Binutils part 1
build_binutils_p1:
	mkdir -p $(TOOLCHAIN_ROOT) && \
	cd binutils-gdb && mkdir -p build && cd build && \
	../configure --prefix=$(TOOLCHAIN_ROOT) --target=$(TARGET) --with-sysroot=$(ROOT_PROJ) --disable-nls --enable-gprofng=no --disable-werror && \
	make -j$(shell nproc) && make install

# Extract linux-headers
linux-headers:
	cd linux && make mrproper && make headers -j$(shell nproc) && \
	find usr/include -type f ! -name '*.h' -delete && \
	mkdir -p $(ROOT_PROJ)/usr/include && \
	cp -rv usr/include $(ROOT_PROJ)/usr

# GNU's Libc
build_glibc:
	ln -sfv ../lib/ld-linux-x86-64.so.2 $(ROOT_PROJ)/lib64
	ln -sfv ../lib/ld-linux-x86-64.so.2 $(ROOT_PROJ)/lib64/ld-lsb-x86-64.so.3
	cd glibc && mkdir -p build && cd build && \
	echo "rootsbindir=/usr/sbin" > configparms && \
	../configure --prefix=/usr  --without-selinux --host=$(TARGET) --build=$$(../scripts/config.guess) --enable-kernel=3.2 --with-headers=$(ROOT_PROJ)/usr/include libc_cv_slibdir=/usr/lib && \
	make -j$(shell nproc) && make DESTDIR=$(ROOT_PROJ) install
	sed '/RTLDLIST=/s@/usr@@g' -i $(ROOT_PROJ)/usr/bin/ldd
	$(TOOLCHAIN_ROOT)/libexec/gcc/$(TARGET)/12.2.0/install-tools/mkheaders

# The compiler, part 1
build_gcc_p1:
	@if [ ! -f gmp-6.2.1.tar.xz ]; then wget https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz; else echo "gmp-6.2.1.tar.xz already exists."; fi
	@if [ ! -f mpc-1.3.1.tar.gz ]; then wget https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz; else echo "mpc-1.3.1.tar.gz already exists."; fi
	@if [ ! -f mpfr-4.2.0.tar.xz ]; then wget https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.0.tar.xz; else echo "mpfr-4.2.0.tar.xz already exists."; fi
	@if [ `uname -m` = 'x86_64' ]; then sed -e '/m64=/s/lib64/lib/' -i.orig gcc/gcc/config/i386/t-linux64; fi
	@if [ -f mpfr-4.2.0.tar.xz ] && [ ! -d gcc/mpfr ]; then tar -xf mpfr-4.2.0.tar.xz && mv -v mpfr-4.2.0 gcc/mpfr; else echo "mpfr-4.2.0.tar.xz not found or directory already exists."; fi
	@if [ -f gmp-6.2.1.tar.xz ] && [ ! -d gcc/gmp ]; then tar -xf gmp-6.2.1.tar.xz && mv -v gmp-6.2.1 gcc/gmp; else echo "gmp-6.2.1.tar.xz not found or directory already exists."; fi
	@if [ -f mpc-1.3.1.tar.gz ] && [ ! -d gcc/mpc ]; then tar -xf mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 gcc/mpc; else echo "mpc-1.3.1.tar.gz not found or directory already exists."; fi
	mkdir -p gcc/build && \
	cd gcc/build && \
	../configure --target=$(TARGET) --prefix=$(TOOLCHAIN_ROOT) --disable-nls --disable-shared --disable-multilib --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --with-glibc-version=2.37 --with-sysroot=$(ROOT_PROJ) --with-newlib --enable-default-pie --enable-default-ssp --enable-languages=c,c++ --without-headers && \
	make -j$(shell nproc) && make install

# The GNU C Standard Library
build_libstdc:
	cd gcc && rm -rf build && mkdir -p build && cd build && \
	../libstdc++-v3/configure \
	--host=$(TARGET) \
	--build=$(../config.guess) \
	--prefix=/usr \
	--disable-multilib \
	--disable-nls \
	--disable-libstdcxx-pch \
	--with-gxx-include-dir=/tools/$(TARGET)/include/c++/12.2.0 \
	&& make -j$(shell nproc) && make DESTDIR=$(ROOT_PROJ) install && \
 	rm -v $(ROOT_PROJ)/usr/lib/libstdc++.la && \
	rm -v $(ROOT_PROJ)/usr/lib/libstdc++fs.la && \
	rm -v $(ROOT_PROJ)/usr/lib/libsupc++.la

build_m4:
	@if [ ! -f m4-1.4.19.tar.xz ]; then wget http://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz; fi
	@if [ -f m4-1.4.19.tar.xz ] && [ ! -d m4 ]; then tar -xf m4-1.4.19.tar.xz && mv -v m4-1.4.19 m4; fi
	cd m4 && \
	autoconf && \
	./configure --prefix=/usr \
	--host=$(TARGET) \
	--build=$$(build-aux/config.guess) && \
	make -j$(shell nproc) && make DESTDIR=$(ROOT_PROJ) install

build_ncurses:
	cd ncurses && mkdir -p build && \
	cd build && \
		../configure && \
		make -C include && \
		make -C progs tic && \
	cd .. && \
	./configure --prefix=/usr                \
            --host=$(TARGET)              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-normal             \
            --with-cxx-shared            \
            --without-debug              \
            --without-ada                \
            --disable-stripping          \
            --enable-widec				&& \
			make -j$(shell nproc) && make DESTDIR=$(ROOT_PROJ) TIC_PATH=$(pwd)/build/progs/tic install && \
			echo "INPUT(-lncursesw)" > $(ROOT_PROJ)/usr/lib/libncurses.so

build_bash:
	cd bash && mkdir -p build && \
	cd build && ../configure --prefix=/usr                      \
            --build=$(shell support/config.guess) \
            --host=$(TARGET)                    \
            --without-bash-malloc			&& \
	make -j$(shell nproc) && make DESTDIR=$(ROOT_PROJ) install && \
	ln -sv bash $(ROOT_PROJ)/bin/sh

build_coreutils:
	cd coreutils && ./bootstrap && mkdir -p build && \
	cd build && ../configure --prefix=/usr                     \
            --host=$(TARGET)                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime	&& \
	make -j$(shell nproc) && make DESTDIR=$(ROOT_PROJ) install && \
	mv -v $(ROOT_PROJ)/usr/bin/chroot              $(ROOT_PROJ)/usr/sbin && \
	mkdir -pv $(ROOT_PROJ)/usr/share/man/man8 && \
	mv -v $(ROOT_PROJ)/usr/share/man/man1/chroot.1 $(ROOT_PROJ)/usr/share/man/man8/chroot.8 && \
	sed -i 's/"1"/"8"/'                    $(ROOT_PROJ)/usr/share/man/man8/chroot.8 

build_diffutils:
	cd diffutils && ./bootstrap && mkdir -p build && \
	cd build && ../configure --prefix=/usr                     \
            --host=$(TARGET)                   && \
	make -j$(shell nproc) && make DESTDIR=$(ROOT_PROJ) install


build_file:
	cd file && mkdir -p build && \
	autoreconf -f -i && \
	cd build && ../configure --disable-bzlib      \
               --disable-libseccomp \
               --disable-xzlib      \
               --disable-zlib && \
	make -j$(shell nproc) && ../configure --prefix=/usr --host=$(TARGET) --build=$(./config.guess) && \
	make FILE_COMPILE=$(shell pwd)/file && make DESTDIR=$(ROOT_PROJ) install && rm -v $(ROOT_PROJ)/usr/lib/libmagic.la

build_findutils:
	cd findutils && \
	./bootstrap && \
	mkdir -p build && cd build && ../configure --prefix=/usr                   \
            --localstatedir=/var/lib/locate \
            --host=$(TARGET)                 \
			--prefix=/usr \
            --build=$(build-aux/config.guess) && \
	make -j$(shell nproc) && make DESTDIR=$(ROOT_PROJ) install

clean:
	rm -rf $(BINUTILS_BUILD_DIR) $(GCC_BUILD_DIR) $(GLIBC_BUILD_DIR) && \
	rm -rf linux/ && \
	repo sync

