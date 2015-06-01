#!/usr/bin/env bash

arg0=$1
get_target() {
  local target_default=$HOME/.opam/system

  target=${arg0}
  if [ -z "${target}" ]; then
    target=${target_default}
  fi
  target_help="Specifies the target installation directory. Defaults to ${target_default}"
}


get_url() {

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
    url="http://sourceforge.net/projects/potassco/files/aspcud/1.9.1/aspcud-1.9.1-win64.zip"
  fi
}


fetch_package() {

  local base=$(basename ${url})
  base="${base%.*}"
  filename="${base%.*}"

  compressed_pkg=${filename}.tar.gz

 wget --no-check-certificate --output-document=${compressed_pkg} ${url}

 if [ $? -gt 0 ]; then
    echo Failed to fetch package from \"${url}\".
    exit 1
 fi

}


decompress(){
 gzip -f -d ${compressed_pkg}

 if [ $? -gt 0 ]; then
    echo Failed to unzip package \"${compressed_pkg}\".
    exit 1
 fi

 tar xvf ${filename}.tar
 
 if [ $? -gt 0 ]; then
    echo Failed to untar package \"${filename}.tar\".
    exit 1
 fi

 
}

preinstall_clean() {
  rm -rf ${filename}/examples
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
  cp -f ${filename}/* ${target}/bin/

}

setup_env() {

  local solver_var="OPAMEXTERNALSOLVER"
  local solver_path=${target}/bin
  local solver_bin=${solver_path}/aspcud
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

}

check_if_installed() {

res=`which aspcud`

if [ ! -z "${res}" ]; then
  echo aspcud already installed at \"${res}\".
  exit 0
fi

}

run() {
  get_target
  get_url
  fetch_package
  decompress
  preinstall_clean
  install
  setup_env
}

check_if_installed
run
