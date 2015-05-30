#!/bin/bash
COMPILER_VERSION=4.02.1
OPAM_VERSION=1.2.2
ROOT_DIR=$HOME/local
SCRIPTS_DIR=$(dirname $0)

# Fetch and extract opam
rm -rf opam-${OPAM_VERSION}*
wget --no-check-certificate https://github.com/ocaml/opam/archive/${OPAM_VERSION}.tar.gz -O opam-${OPAM_VERSION}.tar.gz
gzip -d opam-${OPAM_VERSION}.tar.gz
tar -xvf opam-${OPAM_VERSION}.tar

# Bootstrap ocaml, biuld and install opam
cd opam-${OPAM_VERSION}
make cold CONFIGURE_ARGS="--prefix ${ROOT_DIR} --disable-certificate-check"
make install
cd ..

echo "Adding $ROOT_DIR/bin and $ROOT_DIR/sbin to path:"
echo "export PATH=$PATH:$ROOT_DIR/bin:$ROOT_DIR/sbin"

export PATH=$PATH:$ROOT_DIR/bin:$ROOT_DIR/sbin


echo "Initializing opam with compiler version ${COMPILER_VERSION}"
# Initialize opam with compiler version
opam init --comp=${COMPILER_VERSION} -y --auto-setup
eval `opam config env`

echo "Pinning customized ocamlscript version"
opam pin add -y -k git ocamlscript https://github.com/struktured/ocamlscript#stable

echo "Pinning shell support"
opam pin add -y -k git shell-support https://github.com/struktured/ocaml-shell-support#stable


echo "Installing some basic packages"
opam install -y extlib re cmdliner fileutils containers

echo "Editing your environment variables for opam..."
$SCRIPTS_DIR/update-env.ml $ROOT_DIR
echo
echo "Done! Relogin your shell or do \"source ~/.bash_profile\" to"
echo "refresh your current one. Run \"opam install utop\" for an interactive shell."
