#!/bin/bash
mkdir -p toolchain/
export TOOLCHAIN_ROOT=$(pwd)/toolchain/
export LFS_TGT=$(uname -m)-lfs-linux-gnu

echo "Building binutils (1/2)..."
cd binutils-gdb
mkdir -p build && cd build

../configure  \
   --prefix=$TOOLCHAIN_ROOT \
   --target=$LFS_TGT \
   --with-sysroot=$TOOLCHAIN_ROOT \
   --disable-nls \
   --enable-gprofng=no \
   --disable-werror \
    && make -j$(nproc) && make install

cd ../../

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
  make -j$(nproc) && make install

cd ../../

echo "Building Linux Headers ..."
cd linux
make mrproper
make headers -j$(nproc)
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $TOOLCHAIN_ROOT/usr

cd ../
echo "building glibc (1/2)..."

cd glibc/
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $TOOLCHAIN_ROOT/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $TOOLCHAIN_ROOT/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $TOOLCHAIN_ROOT/lib64/ld-lsb-x86-64.so.3     ;;
esac

mkdir build && cd build

echo "rootsbindir=/usr/sbin" > configparms

../configure                                       \
    --prefix=$TOOLCHAIN_ROOT                        \
    --host=$LFS_TGT                                \
    --build=$(../scripts/config.guess)              \
    --enable-kernel=3.2                            \
    --with-headers=$TOOLCHAIN_ROOT/include          \
    libc_cv_slibdir=/usr/lib &&
    make -j$(nproc) &&
    make DESTDIR=$TOOLCHAIN_ROOT/ install

sed '/RTLDLIST=/s@/usr@@g' -i TOOLCHAIN_ROOT/usr/bin/ldd

echo 'int main(){}' | $LFS_TGT-gcc -xc -readelf -l a.out | grep ld-linux
rm -v a.out
TOOLCHAIN_ROOT/libexec/gcc/$LFS_TGT/12.2.0/install-tools/mkheaders

cd ../../


