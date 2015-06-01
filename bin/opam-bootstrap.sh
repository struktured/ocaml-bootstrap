#!/bin/bash
COMPILER_VERSION=4.02.1
OPAM_VERSION=1.2.2

DEFAULT_ROOT_DIR=$HOME/.opam/system
ROOT_DIR=$1
SCRIPTS_DIR=$(dirname $0)

install_aspcud() {

if [ -z ${ROOT_DIR} ]; then
 echo No target specified, will install opam and native dependencies into \"${DEFAULT_ROOT_DIR}\"
 ROOT_DIR=$DEFAULT_ROOT_DIR
fi

  # Install aspcud if we need to first
$SCRIPTS_DIR/install-local/install-aspcud.sh $ROOT_DIR

if [ $? -gt 0 ]; then
    echo "ERROR: Failed to install aspcud, which opam requires. Cannot continue."
    echo "See http://sourceforge.net/projects/potassco/files/aspcud/ to install manually"
    exit 1
fi

}

fetch_opam() {
# Fetch and extract opam
rm -rf opam-${OPAM_VERSION}*
wget --no-check-certificate https://github.com/ocaml/opam/archive/${OPAM_VERSION}.tar.gz -O opam-${OPAM_VERSION}.tar.gz

if [ $? -gt 0 ]; then
    echo "ERROR: Failed to fetch opam source. Cannot continue."
    exit 1
fi
}

uncompress_opam() {
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
}

bootstrap_opam() {
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
}

init_opam() {
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
}

setup_env() {

  local opam_bin_root=${ROOT_DIR}/bin

  export PATH=$PATH:${opam_bin_root}

  local path_string_cmt="# Add location of opam binary"
  local path_string="export PATH=\$PATH:${opam_bin_root}"
  profile=""
  if [ -e "$HOME/.bash_profile" ]; then
     profile=$HOME/.bash_profile 
  elif [ -e "$HOME/.profile" ]; then
     profile=$HOME/.profile
  elif [ -e "$HOME/.bashrc" ]; then
     profile=$HOME/.bashrc   
  else
      echo "******************************************************************"
      echo "WARNING: No profile script found in your home directory to update!"
      echo "Please manually add the following to your shell start script: "
      echo "------------------------------------------------------------------"
      echo ${path_string}
  fi

  path_txt=`grep -o "${opam_bin_root}" ${profile}`

  if [ -z "${path_txt}" ]; then
    echo "Adding \"${opam_bin_root}\" to path in ${profile}" 
    echo ${path_string_cmt} >> ${profile}
    echo ${path_string} >> ${profile}
  fi

}

check_if_installed() {

res=`which opam`

if [ ! -z "${res}" ]; then
  echo opam already installed at \"${res}\". 
  exit 1
fi

}


show_done() {
echo ---------------------------------------------------
echo 
echo Done! *Relogin your shell* to update your environment.
echo 
echo To bootstrap more native dependencies, you need 
echo ocaml-profiles first. To install it, run
echo "bin/ocaml-profiles-bootstrap.sh", then you may 
echo execute the ocamlscripts located in "bin/install-local"
}

run() {
  check_if_installed
  install_aspcud
  fetch_opam
  uncompress_opam
  bootstrap_opam
  setup_env
  init_opam
  show_done
}

run

