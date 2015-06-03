#!/bin/bash
COMPILER_VERSION=4.02.1
OPAM_VERSION=1.2.2

DEFAULT_ROOT_DIR=$HOME/local

SCRIPTS_DIR=$(dirname $0)

args="$@"

root_dir_arg() {
  for arg in ${args}
  do
    if [[ ${arg} != -* ]]; then
      ROOT_DIR=${arg}
      break
    fi
  done

  if [ -z "${ROOT_DIR}" ]; then
    echo No target specified, will install opam and native dependencies into \"${DEFAULT_ROOT_DIR}\"
    ROOT_DIR=$DEFAULT_ROOT_DIR
  fi
}

no_check_certificate_arg() {
  no_check_certificate=""
  for arg in ${args}
  do
    if [ "${arg}" = "--no-check-certificate" ]; then
      no_check_certificate=${arg}
    fi
  done
}

install_aspcud() {
  # Install aspcud if we need to first
  $SCRIPTS_DIR/install-local/install-aspcud.sh $ROOT_DIR ${no_check_certificate}
  
  if [ $? -gt 0 ]; then
    echo "ERROR: Failed to install aspcud, which opam requires. Cannot continue."
    echo "See http://sourceforge.net/projects/potassco/files/aspcud/ to install manually"
    exit 1
  fi

  local aspcud_bin=`which aspcud`
  local aspcud_dir=$(dirname ${aspcud_bin})

  if [ -e "${aspcud_bin}" ]; then 
    echo Found ascpud at "${ascpud_bin}". Exporting...
    export PATH=$PATH:${aspcud_dir}
    export OPAMEXTERNALSOLVER=${aspcud_bin}
  else
    aspcud_bin=$ROOT_DIR/bin/aspcud
    aspcud_dir=$ROOT_DIR/bin
    if [ -e "${aspcud_bin}" ]; then
      echo Found solver in opam root directory at "${aspcud_dir}". Exporting...
      export PATH=$PATH:${aspcud_dir}
      export OPAMEXTERNALSOLVER=${aspcud_bin}
    else 
      echo WARNING: aspcud not found. Checking for external solver...
      if [ -e "$OPAMEXTERNALSOLVER" ]; then 
        echo Found external solver "$OPAMEXTERNALSOLVER". Will try using it.
      else
	echo ERROR: Cannot install aspcud and no external solver found. Cannot continue.
	exit 1
      fi
    fi
  fi

}

fetch_opam() {
  # Fetch and extract opam
  rm -rf opam-${OPAM_VERSION}*
  wget ${no_check_certificate} https://github.com/ocaml/opam/archive/${OPAM_VERSION}.tar.gz -O opam-${OPAM_VERSION}.tar.gz

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
  local opam_lib_root=${ROOT_DIR}/lib

  export PATH=$PATH:${opam_bin_root}
  export LIBRARY_PATH=$LIBRARY_PATH:${opam_lib_root}
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LIBRARY_PATH

  local path_string_cmt="# Add location of opam binary to PATH"
  local path_string="export PATH=\$PATH:${opam_bin_root}"
  local path_string_search="export PATH=\\$PATH:${opam_bin_root}"

  local lib_string_cmt="# Add location of opam lib root to LIBRARY_PATH"
  local lib_string="export LIBRARY_PATH=\$LIBRARY_PATH:${opam_lib_root}"
  local lib_string_search="export LIBRARY_PATH=\\$LIBRARY_PATH:${opam_lib_root}"

  local ld_string_cmt="# Add location of opam lib root to LD_LIBRARY_PATH"
  local ld_string="export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${opam_lib_root}"
  local ld_string_search="export LD_LIBRARY_PATH=\\$LIBRARY_PATH:${opam_lib_root}"

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

  if [ -e "${profile}" ]; then
    path_txt=`grep -o "${path_string_search}" ${profile}`

    if [ -z "${path_txt}" ]; then
      echo Adding \"${opam_bin_root}\" to PATH in ${profile}
      echo ${path_string_cmt} >> ${profile}
      echo ${path_string} >> ${profile}
    else
      echo Found "${path_txt}" no need to edit your profile
    fi 

    library_txt=`grep -o "${lib_string_search}" ${profile}`

    if [ -z "${library_txt}" ]; then
      echo "Adding \"${opam_lib_root}\" to LIBRARY_PATH in ${profile}"
      echo ${lib_string_cmt} >> ${profile}
      echo ${lib_string} >> ${profile}
    fi

    ld_txt=`grep -o "${ld_string_search}" ${profile}`

    if [ -z "${ld_txt}" ]; then
      echo "Adding \"${opam_lib_root}\" to LD_LIBRARY_PATH in ${profile}"
      echo ${ld_string_cmt} >> ${profile}
      echo ${ld_string} >> ${profile}
    fi

  fi


}

check_if_installed() {

  res=`which opam`

  if [ ! -z "${res}" ]; then

    force=""
    for arg in ${args}
    do
      if [ "${arg}" = "--force" ]; then
        force="true"
      fi
    done

    if [ -z "${force}" ] ; then
      echo opam already installed at \"${res}\". Do --force to install anyhow.
      exit 1
    fi
  fi

}


show_done() {
  echo -------------------------------------------------------------------------------
  echo
  echo Done! OCaml and opam installed! *Relogin your shell* to update your
  echo environment. Optionally, you may choose to bootstrap more packages or native
  echo dependencies, but you need ocamlscript and ocaml-profiles first. To install, run
  echo
  echo "  "bin/ocaml-profiles-bootstrap.sh
  echo
  echo followed by
  echo
  echo "  "ocaml-profiles ocamlscript
  echo
  echo You may then execute the ocaml scripts located in "bin/install-local/*"
  echo or simply check out profiles by running
  echo
  echo "  "ocaml-profiles list
  echo
  echo See https://github.com/struktured/ocaml-profiles for more information.
}


show_help() {
  echo Usage:
  echo "  "ocaml-bootstrap.sh \<OPAM_SYSTEM_ROOT\>
  echo
  echo Description:
  echo "  "Bootstraps an OCaml and Opam installation from scratch.
  echo "  "Argument OPAM_SYSTEM_ROOT defaults to directory "$HOME/.opam/system"
  echo
  echo Requirements:
  echo "  "A unix like environment with build capabilities, including packages
  echo "  "pkg-config, m4, curl, and optionally pcre, cmake, and gsl. Try one of
  echo
  echo "    "bin/install-system/install-ubuntu-deps.sh  \(for ubuntu users\)
  echo "    "bin/install-system/install-redhat-deps.sh  \(for redhat/fedora users\)
  echo "    "bin/install-system/install-brew-deps.sh    \(for osx+brew users\)
  echo "    "bin/install-system/install-macport-deps.sh \(for osx+macport users\)
  echo
  echo Contact:
  echo "  "Visit https://github.com/struktured/ocaml-bootstrap for more info.
  echo

}

maybe_show_help() {
  for arg in ${args}
  do
    if [ "${arg}" = "--help" ]; then
      show_help
      exit 1
    fi
  done
}

run() {
  maybe_show_help
  check_if_installed
  root_dir_arg
  no_check_certificate_arg
  install_aspcud
  fetch_opam
  uncompress_opam
  bootstrap_opam
  setup_env
  init_opam
  show_done
}

run

