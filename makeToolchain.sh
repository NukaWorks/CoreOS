#!/bin/bash
mkdir -p toolchain/
export TOOLCHAIN_ROOT=./toolchain/
export LFS_TGT=(uname -m)-lfs-linux-gnu

echo "Building binutils (1/2)..."
cd binutils
mkdir -p build && cd build

../configure --prefix=$TOOLCHAIN_ROOT --target=$LFS_TGT --disable-nls --disable-werror && make && make install

cd ../.

echo "Building GCC (1/2)..."
cp -rvf mpfr gmp mpc gcc/
cd gcc

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64  ;;
esac

mkdir -p build && cd build

../configure \
  --target=$LFS_TGT \
  --prefix=$TOOLCHAIN_ROOT \
  --disable-nls \
  --disable-shared \
  --disable-multilib \
  --disable-threads \
  --disable-libatomic \
  --disable-libgomp \
  --disable-libquadmath \
  --disable-libssp \
  --disable-libvtv \
  --disable-libstdcxx \
  --with-glibc-version=2.37 \
  --with-sysroot=$TOOLCHAIN_ROOT \
  --with-newlib \
  --enable-default-pie \
  --enable-default-ssp \
  --enable-languages=c,c++ \
  --without-headers &&
  make && make install

