#!/bin/bash
COMPILER_VERSION=4.02.1
OPAM_VERSION=1.2.2

DEFAULT_ROOT_DIR=$HOME/.opam/system
ROOT_DIR=$1

if [ -z ${ROOT_DIR} ]; then
 echo No target specified, will install opam and native dependencies into \"${DEFAULT_ROOT_DIR}\"
 ROOT_DIR=$DEFAULT_ROOT_DIR
fi

SCRIPTS_DIR=$(dirname $0)

# Install aspcud if we need to first
$SCRIPTS_DIR/install-local/install_aspcud.sh $ROOT_DIR
if [ $? -gt 0 ]; then
    echo "ERROR: Failed to install aspcud, which opam requires. Cannot continue."
    echo "See http://sourceforge.net/projects/potassco/files/aspcud/ to install manually"
    exit 1
fi

# Fetch and extract opam
rm -rf opam-${OPAM_VERSION}*
wget --no-check-certificate https://github.com/ocaml/opam/archive/${OPAM_VERSION}.tar.gz -O opam-${OPAM_VERSION}.tar.gz

if [ $? -gt 0 ]; then
    echo "ERROR: Failed to fetch opam source. Cannot continue."
    exit 1
fi

gzip -d opam-${OPAM_VERSION}.tar.gz

if [ $? -gt 0 ]; then
    echo "ERROR: Failed to unzip opam source. Cannot continue."
    exit 1
fi

tar -xvf opam-${OPAM_VERSION}.tar

if [ $? -gt 0 ]; then
    echo "ERROR: Failed to untar opam source. Cannot continue."
    exit 1
fi

# Bootstrap ocaml, build and install opam
cd opam-${OPAM_VERSION}

if [ $? -gt 0 ]; then
    echo "ERROR: Couldn't enter build directory. Cannot continue."
    exit 1
fi

make cold CONFIGURE_ARGS="--prefix ${ROOT_DIR} --disable-certificate-check"

if [ $? -gt 0 ]; then
    echo "ERROR: Couldn't compile opam. Cannot continue."
    cd ..
    exit 1
fi

make install

if [ $? -gt 0 ]; then
    echo "ERROR: Couldn't install opam. Cannot continue."
    cd ..
    exit 1
fi

cd ..

echo "Temporarily adding $ROOT_DIR/bin to path as: "
echo "export PATH=$PATH:$ROOT_DIR/bin"

export PATH=$PATH:$ROOT_DIR/bin:$ROOT_DIR/sbin

echo "Initializing opam with compiler version ${COMPILER_VERSION}"
# Initialize opam with compiler version
opam init --comp=${COMPILER_VERSION} -y --auto-setup

if [ $? -gt 0 ]; then
    echo "ERROR: Couldn't initialize opam repository. Cannot continue."
    exit 1
fi

eval `opam config env`

echo ---------------------------------------------------
echo 
echo Done! Relogin your shell to update your environment.
echo Run \"opam install utop\" for an interactive shell.
