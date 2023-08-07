ROOT_PROJ = /mnt/coreos
TOOLCHAIN_ROOT := $(ROOT_PROJ)/tools
TARGET := $(shell uname -m)-coreos-linux-gnu
BINUTILS_BUILD_DIR := binutils-gdb/build
GCC_BUILD_DIR := gcc/build
GLIBC_BUILD_DIR := glibc/build

all: prep binutils gccbuild linux-headers glibcbuild libstdc

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

binutils:
	mkdir -p $(TOOLCHAIN_ROOT) && \
	cd binutils-gdb && mkdir build && cd build && \
	../configure --prefix=$(TOOLCHAIN_ROOT) --target=$(TARGET) --with-sysroot=$(ROOT_PROJ) --disable-nls --enable-gprofng=no --disable-werror && \
	make -j$(shell nproc) && make install

linux-headers:
	cd linux && make mrproper && make headers -j$(shell nproc) && \
	find usr/include -type f ! -name '*.h' -delete && \
	mkdir -p $(ROOT_PROJ)/usr/include && \
	cp -rv usr/include $(ROOT_PROJ)/usr

glibcbuild:
	ln -sfv ../lib/ld-linux-x86-64.so.2 $(ROOT_PROJ)/lib64
	ln -sfv ../lib/ld-linux-x86-64.so.2 $(ROOT_PROJ)/lib64/ld-lsb-x86-64.so.3
	cd glibc && mkdir -p build && cd build && \
	echo "rootsbindir=/usr/sbin" > configparms && \
	../configure --prefix=/usr --host=$(TARGET) --build=$$(../scripts/config.guess) --enable-kernel=3.2 --with-headers=$(ROOT_PROJ)/usr/include libc_cv_slibdir=/usr/lib && \
	make -j$(shell nproc) && make DESTDIR=$(ROOT_PROJ) install
	sed '/RTLDLIST=/s@/usr@@g' -i $(ROOT_PROJ)/usr/bin/ldd
	$(TOOLCHAIN_ROOT)/libexec/gcc/$(TARGET)/12.2.0/install-tools/mkheaders

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
	../configure --target=$(TARGET) --prefix=$(TOOLCHAIN_ROOT) --disable-nls --disable-shared --disable-multilib --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --with-glibc-version=2.37 --with-sysroot=$(ROOT_PROJ) --with-newlib --enable-default-pie --enable-default-ssp --enable-languages=c,c++ --without-headers && \
	make -j$(shell nproc) && make install


libstdc:
	cd gcc && rm -rf build && mkdir -p build && cd build && \
	../libstdc++-v3/configure \
	--host=$(TARGET) \
	--build=$(../config.guess) \
	--prefix=/usr \
	--disable-multilib \
	--disable-nls \
	--disable-libstdcxx-pch \
	--with-gxx-include-dir=/tools/$(TARGET)/include/c++/12.2.0 \
	&& make -j$(shell nproc) && make DESTDIR=$(ROOT_PROJ) install

clean-static:
	rm -v $(ROOT_PROJ)/usr/lib/libstdc++.la
	rm -v $(ROOT_PROJ)/usr/lib/libstdc++fs.la
	rm -v $(ROOT_PROJ)/usr/lib/libsupc++.la

clean:
	rm -rf $(BINUTILS_BUILD_DIR) $(GCC_BUILD_DIR) $(GLIBC_BUILD_DIR)
