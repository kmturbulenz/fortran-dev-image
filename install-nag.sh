#!/bin/bash
# This script require environment variable NAG_VER to be set

set -o errexit
set -o pipefail

NAG_URL="https://monet.nag.co.uk/compiler/r72download/npl6a72na_amd64_${NAG_VER}.tgz"
NAG_ROOT_DIR="/opt/nag"

mkdir -p $NAG_ROOT_DIR
cd $NAG_ROOT_DIR

wget --no-verbose $NAG_URL
tar -xf npl6a72na_amd64_${NAG_VER}.tgz
rm npl6a72na_amd64_${NAG_VER}.tgz

export INSTALL_TO_BINDIR="$NAG_ROOT_DIR/bin"
export INSTALL_TO_LIBDIR="$NAG_ROOT_DIR/lib/NAG_Fortran"
cd NAG_Fortran-amd64
./INSTALLU.sh 2>&1 | tee ../nag-install.log
cd -

rm -rf NAG_Fortran-amd64

