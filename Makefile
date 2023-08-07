ROOT_PROJ = $(shell pwd)/
TOOLCHAIN_ROOT := $(shell pwd)/tools
LFS_TGT := $(shell uname -m)-coreos-linux-gnu
BINUTILS_BUILD_DIR := binutils-gdb/build
GCC_BUILD_DIR := gcc/build
GLIBC_BUILD_DIR := glibc/build

all: prep binutils gccbuild linux-headers glibcbuild libstdc

prep:
	mkdir -pv $(TOOLCHAIN_ROOT)
	mkdir -pv $(TOOLCHAIN_ROOT)/etc
	mkdir -pv $(TOOLCHAIN_ROOT)/var
	mkdir -pv $(TOOLCHAIN_ROOT)/bin
	mkdir -pv $(TOOLCHAIN_ROOT)/sbin
	mkdir -pv $(TOOLCHAIN_ROOT)/lib
	if [ `uname -m` = 'x86_64' ]; then mkdir -pv $(TOOLCHAIN_ROOT)/lib64; fi

binutils:
	mkdir -p $(TOOLCHAIN_ROOT) && \
	cd binutils-gdb && mkdir build && cd build && \
	../configure --prefix=$(TOOLCHAIN_ROOT)/ --target=$(LFS_TGT) --with-sysroot=$(TOOLCHAIN_ROOT) --disable-nls --enable-gprofng=no --disable-werror && \
	make -j$(shell nproc) && make install

linux-headers:
	cd linux && make mrproper && make headers -j$(shell nproc) && \
	find usr/include -type f ! -name '*.h' -delete && \
	mkdir -p $(TOOLCHAIN_ROOT)/usr/include
	cp -rv usr/include ../$(TOOLCHAIN_ROOT)/usr

glibcbuild:
	cd glibc && mkdir -p build && cd build && \
	echo "rootsbindir=/usr/sbin" > configparms && \
	../configure --prefix=$(TOOLCHAIN_ROOT) --host=$(LFS_TGT) --build=$$(../scripts/config.guess) --enable-kernel=3.2 --with-headers=$(TOOLCHAIN_ROOT)/include libc_cv_slibdir=/usr/lib && \
	make -j$(shell nproc) && make DESTDIR=$(TOOLCHAIN_ROOT)/ install

gccbuild:
	@if [ ! -f gmp-6.2.1.tar.xz ]; then wget https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz; else echo "gmp-6.2.1.tar.xz already exists."; fi
	@if [ ! -f mpc-1.3.1.tar.gz ]; then wget https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz; else echo "mpc-1.3.1.tar.gz already exists."; fi
	@if [ ! -f mpfr-4.2.0.tar.xz ]; then wget https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.0.tar.xz; else echo "mpfr-4.2.0.tar.xz already exists."; fi
	@if [ `uname -m` = 'x86_64' ]; then sed -e '/m64=/s/lib64/lib/' -i.orig gcc/gcc/config/i386/t-linux64; fi
	@if [ -f mpfr-4.2.0.tar.xz ] && [ ! -d gcc/mpfr ]; then tar -xf mpfr-4.2.0.tar.xz && mv -v mpfr-4.2.0 gcc/mpfr; else echo "mpfr-4.2.0.tar.xz not found or directory already exists."; fi
	@if [ -f gmp-6.2.1.tar.xz ] && [ ! -d gcc/gmp ]; then tar -xf gmp-6.2.1.tar.xz && mv -v gmp-6.2.1 gcc/gmp; else echo "gmp-6.2.1.tar.xz not found or directory already exists."; fi
	@if [ -f mpc-1.3.1.tar.gz ] && [ ! -d gcc/mpc ]; then tar -xf mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 gcc/mpc; else echo "mpc-1.3.1.tar.gz not found or directory already exists."; fi
	mkdir -p gcc/build && \
	cd gcc/build && \
	../configure --target=$(LFS_TGT) --prefix=$(TOOLCHAIN_ROOT) --disable-nls --disable-shared --disable-multilib --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --with-glibc-version=2.37 --with-sysroot=$(TOOLCHAIN_ROOT) --with-newlib --enable-default-pie --enable-default-ssp --enable-languages=c,c++ --without-headers && \
	make -j$(shell nproc) && make install && \
	$(TOOLCHAIN_ROOT)/libexec/gcc/$(LFS_TGT)/12.2.0/install-tools/mkheaders


libstdc:
	cd gcc && rm -rf build && mkdir -p build && cd build && \
	../libstdc++-v3/configure \
	--host=$(LFS_TGT) \
	--build=$(../config.guess) \
	--prefix=/usr \
	--disable-multilib \
	--with-headers \
	--disable-nls \
	--disable-libstdcxx-pch \
	--with-gxx-include-dir=$(LFS_TGT)/include/c++/12.2.0 \
	&& make -j$(shell nproc) && make DESTDIR=$(TOOLCHAIN_ROOT) install

clean:
	rm -rf $(BINUTILS_BUILD_DIR) $(GCC_BUILD_DIR) $(GLIBC_BUILD_DIR)
