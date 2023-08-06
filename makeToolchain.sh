#!/bin/bash

# Create the toolchain directory if necessary
mkdir -p toolchain/
export TOOLCHAIN_ROOT=$(pwd)/toolchain/
export LFS_TGT=$(uname -m)-lfs-linux-gnu

# Build binutils
echo "Building binutils (1/2)..."
cd binutils-gdb
rm -rf build && mkdir build && cd build
../configure --prefix=$TOOLCHAIN_ROOT --target=$LFS_TGT --with-sysroot=$TOOLCHAIN_ROOT --disable-nls --enable-gprofng=no --disable-werror
if make -j$(nproc) && make install; then
    echo "Binutils built successfully."
else
    echo "Binutils build failed." && exit 1
fi
cd ../../

# Build GCC
echo "Building GCC (1/2)..."
cd gcc
rm -rf build && mkdir build && cd build
../configure --target=$LFS_TGT --prefix=$TOOLCHAIN_ROOT --disable-nls --disable-shared --disable-multilib --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --with-glibc-version=2.37 --with-sysroot=$TOOLCHAIN_ROOT --with-newlib --enable-default-pie --enable-default-ssp --enable-languages=c,c++ --without-headers
if make -j$(nproc) && make install; then
    echo "GCC built successfully."
else
    echo "GCC build failed." && exit 1
fi
cd ../../

# Build Linux Headers
echo "Building Linux Headers..."
cd linux
if make mrproper && make headers -j$(nproc); then
    find usr/include -type f ! -name '*.h' -delete
    cp -rv usr/include $TOOLCHAIN_ROOT/usr
    echo "Linux Headers built successfully."
else
    echo "Linux Headers build failed." && exit 1
fi
cd ../

# Build glibc
echo "Building glibc (1/2)..."
cd glibc
rm -rf build && mkdir build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=$TOOLCHAIN_ROOT --host=$LFS_TGT --build=$(../scripts/config.guess) --enable-kernel=3.2 --with-headers=$TOOLCHAIN_ROOT/include libc_cv_slibdir=/usr/lib
if make -j$(nproc) && make DESTDIR=$TOOLCHAIN_ROOT/ install; then
    echo "glibc built successfully."
else
    echo "glibc build failed." && exit 1
fi
cd ../../

# Final setup and cleanup
sed '/RTLDLIST=/s@/usr@@g' -i $TOOLCHAIN_ROOT/usr/bin/ldd
echo 'int main(){}' | $LFS_TGT-gcc -xc -
readelf -l a.out | grep ld-linux
rm -v a.out
$TOOLCHAIN_ROOT/libexec/gcc/$LFS_TGT/12.2.0/install-tools/mkheaders

# End of script
echo "All done."
