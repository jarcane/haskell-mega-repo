#!/bin/sh

# This script is used to build binaries inside the docker
# See mega-repo-tool -h

set -e

# This matters
unset POSIXLY_CORRECT

# Root directory. In docker it's /app/src
if [ "x$DOCKER" = "xYES" ]; then
    echo "Building in Docker"

    ROOTDIR=/app/src
else
    ROOTDIR=$(pwd)
fi

cd $ROOTDIR

make check-dirty
make check-checksums

# GHC version
GHCVER=${GHCVER-8.2.2}
export PATH=/opt/ghc/$GHCVER/bin:$PATH
HC=ghc-$GHCVER

# Print versions
lsb_release -a
${HC} --version
cabal --version

# Update things
if [ "x$DOCKER" = "xYES" ]; then
    apt-get update && apt-get upgrade -y
fi

# Use different BUILDDIR
BUILDDIR=dist-newstyle-prod

# Concurrency
CONCURRENCY=${CONCURRENCY-2}

# Update cabal
cabal update

# Perform build
cabal new-build -j$CONCURRENCY -w $HC --builddir=$BUILDDIR all:exes

# write current git hash, so we know where we are
GITHASH=$(git log --pretty=format:'%h' -n 1 --abbrev=8)

# Copy binaries to ./build/exe/exe
# We put binaries in separate directories to speed-up docker image creation
mkdir -p $ROOTDIR/build
for fullexe in $(cabal-plan --builddir=$BUILDDIR list-bins|grep ':exe:'|awk '{print $2}'); do
    if [ $(echo $fullexe | sed "s:^$ROOTDIR/.*$:matches:") = "matches" ]; then
        exe=$(basename $fullexe)
        mkdir -p  $ROOTDIR/build/$exe
        cp $fullexe $ROOTDIR/build/$exe/$exe
        strip $ROOTDIR/build/$exe/$exe
        echo $GITHASH > $ROOTDIR/build/$exe/git-hash.txt
    else
        echo "Skipping $fullexe"
    fi
done

echo $GITHASH > $ROOTDIR/build/git-hash.txt
