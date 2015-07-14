#!/usr/bin/env bash

SCRIPTS_DIR=$(dirname $0)/../

arg0=$1
get_target() {
  local target_default=$HOME/local

  target=${arg0}
  if [ -z "${target}" ]; then
    target=${target_default}
  fi
  target_help="Specifies the target installation directory. Defaults to ${target_default}"
}


get_url_and_copy_resources() {

  local os_type=$OSTYPE
  local mach_type=$MACHTYPE
 
  # Defaults to 64 bit linux 
  url="http://sourceforge.net/projects/potassco/files/aspcud/1.9.1/aspcud-1.9.1-x86_64-linux.tar.gz"

  if [[ $os_type == *"linux"* ]]; then
    if [[ $mach_type == *"64"* ]]; then
      echo "64 bit Linux detected."
      url="http://sourceforge.net/projects/potassco/files/aspcud/1.9.1/aspcud-1.9.1-x86_64-linux.tar.gz"
    else
      echo "32 bit Linux detected."
      url="http://sourceforge.net/projects/potassco/files/aspcud/1.9.0/aspcud-1.9.0-x86-linux.tar.gz"
    fi
  elif [[ $os_type == *"darwin"* ]]; then
    echo "MacOS detected."
    url="http://sourceforge.net/projects/potassco/files/aspcud/1.9.1/aspcud-1.9.1-macos-10.9.tar.gz"
  elif [[ $os_type == *"win"* ]]; then
    local cygwin_aspcud=$SCRIPTS_DIR/cygwin-support/aspcud.sh
    echo "Windows detected, copying aspcud script \"${cygwin_aspcud}\" to target folder \"${target}/bin\"."
    mkdir -p $target/bin
    cp -f ${cygwin_aspcud} $target/bin
    url="http://sourceforge.net/projects/potassco/files/aspcud/1.9.1/aspcud-1.9.1-win64.zip"
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

fetch_package() {

 local base=$(basename ${url})
 local base2="${base%.*}"
 filename="${base2%.*}"

 compressed_pkg=${base}

 wget ${no_check_certificate} --output-document=${compressed_pkg} ${url}

 if [ $? -gt 0 ]; then
    echo Failed to fetch package from \"${url}\".
    exit 1
 fi

}


decompress() {

  local last_extension=${compressed_pkg##*.}

  if [[ "gz" = "${last_extension}" || "GZ" = "${last_extension}" ]]; then
    gzip -f -d ${compressed_pkg}
    if [ $? -gt 0 ]; then
      echo Failed to uncompress package \"${compressed_pkg}\" with gzip.
      exit 1
    fi
    compressed_pkg=${filename}.tar
    last_extension=tar
  fi

  if [[ "zip" = "${last_extension}" || "ZIP" = "${last_extension}" ]]; then
    unzip ${compressed_pkg}
    if [ $? -gt 0 ]; then
      echo Failed to uncompress package \"${compressed_pkg}\" with unzip.
      exit 1
    fi
    last_extension=""
  fi

  if [[ "tar" = "${last_extension}" || "TAR" = "${last_extension}" ]]; then  
    tar xvf ${filename}.${last_extension}
 
   if [ $? -gt 0 ]; then
      echo Failed to untar package \"${filename}.tar\".
     exit 1
   fi
 fi
 
}

preinstall_clean() {
  if [ ! -z ${filename} ]; then 
    rm -rf ${filename}*/*
  fi
}

install() {
 
  if [ ! -d "${target}/bin" ]; then
    mkdir -p ${target}/bin
    if [ $? -gt 0 ]; then
      echo Failed to make installation directory \"${target}/bin\"
      exit 1
    fi
  fi

  echo Copying binaries to ${target}
  cp -f ${filename}*/* ${target}/bin/

}

setup_env() {

  local solver_var="OPAMEXTERNALSOLVER"
  local solver_path=${target}/bin

  local solver_bin=""
  if [[ $os_type == *"win"* ]]; then
    solver_bin=${solver_path}/aspcud.sh
  else
    solver_bin=${solver_path}/aspcud
  fi

  local solver_string_cmt="# Set explicit external solver location for opam installations"
  local solver_string="export ${solver_var}=${solver_bin}"

  export PATH=$PATH:${solver_path}
  export ${solver_string}
  local path_string_cmt="# Add location of aspcud solver to path"
  local path_string="export PATH=\$PATH:${solver_path}"
  profile=""
  if [ -e "$HOME/.bash_profile" ]; then
     profile=$HOME/.bash_profile 
  elif [ -e "$HOME/.profile" ]; then
     profile=$HOME/.profile
  elif [ -e "$HOME/.bashrc" ]; then
     profile=$HOME/.bashrc   
  else
      echo "WARNING: No profile script found in your home directory to update!"
      echo "Please manually add the following to your shell start script: "
      echo "---------------------------------------------------------------"
      echo ${path_string}
      echo ${solver_string}
  fi

  if [ ! -z ${profile} ]; then 
    solver_var_txt=`grep -o ${solver_var} ${profile}`

    if [ -z "${solver_var_txt}" ]; then
      echo "Adding \"${solver_var}\" to ${profile}" 
      echo ${solver_string_cmt} >> ${profile}
      echo ${solver_string} >> ${profile}
    fi

    path_txt=`grep -o \"${solver_path}\" ${profile}`

    if [ -z "${path_txt}" ]; then
      echo "Adding \"${solver_path}\" to path in ${profile}" 
      echo ${path_string_cmt} >> ${profile}
      echo ${path_string} >> ${profile}
    fi
  fi
}

check_if_installed() {

res=`which aspcud`

if [ ! -z "${res}" ]; then
  echo aspcud already installed at \"${res}\".
  exit 0
fi

}

run() {
  no_check_certificate_arg
  get_target
  get_url_and_copy_resources
  fetch_package
  preinstall_clean 
  decompress
  install
  setup_env
}

check_if_installed
run
