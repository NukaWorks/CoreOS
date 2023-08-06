TOOLCHAIN_ROOT := $(shell pwd)/toolchain
LFS_TGT := $(shell uname -m)-linux-gnu
BINUTILS_BUILD_DIR := binutils-gdb/build
GCC_BUILD_DIR := gcc/build
GLIBC_BUILD_DIR := glibc/build

all: binutils gccbuild linux-headers glibc libstdc

binutils:
	mkdir -p $(TOOLCHAIN_ROOT) \
	cd binutils-gdb && mkdir build && cd build && \
	../configure --prefix=$(TOOLCHAIN_ROOT) --target=$(LFS_TGT) --with-sysroot=$(TOOLCHAIN_ROOT) --disable-nls --enable-gprofng=no --disable-werror && \
	make -j$(shell nproc) && make install

linux-headers:
	cd linux && make mrproper && make headers -j$(shell nproc) && \
	find usr/include -type f ! -name '*.h' -delete && \
	cp -rv usr/include $(TOOLCHAIN_ROOT)/usr

glibc:
	cd glibc && mkdir build && cd build && \
	echo "rootsbindir=/usr/sbin" > configparms && \
	../configure --prefix=$(TOOLCHAIN_ROOT) --host=$(LFS_TGT) --build=$$(../scripts/config.guess) --enable-kernel=3.2 --with-headers=$(TOOLCHAIN_ROOT)/include libc_cv_slibdir=/usr/lib && \
	make -j$(shell nproc) && make DESTDIR=$(TOOLCHAIN_ROOT)/ install

gccbuild:
	cd gcc && \
	mkdir -p build && \
	cd build && \
	../configure --target=$(LFS_TGT) --prefix=$(TOOLCHAIN_ROOT) --disable-nls --disable-shared --disable-multilib --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --with-glibc-version=2.37 --with-sysroot=$(TOOLCHAIN_ROOT) --with-newlib --enable-default-pie --enable-default-ssp --enable-languages=c,c++ --without-headers && \
	make -j$(shell nproc) && make install && \
	$(TOOLCHAIN_ROOT)/libexec/gcc/$(LFS_TGT)/12.2.0/install-tools/mkheaders

libstdc:
	cd gcc && rm -rf build && mkdir build && cd build && \
	../libstdc++-v3/configure \
	--host=$(LFS_TGT) \
	--build=$(../config.guess) \
	--prefix=/usr \
	--disable-multilib \
	--disable-nls \
	--disable-libstdcxx-pch \
	--with-gxx-include-dir=$(LFS_TGT)/include/c++/12.2.0 \
	&& make -j$(shell nproc) && make DESTDIR=$(TOOLCHAIN_ROOT) install

clean:
	rm -rf $(BINUTILS_BUILD_DIR) $(GCC_BUILD_DIR) $(GLIBC_BUILD_DIR)
