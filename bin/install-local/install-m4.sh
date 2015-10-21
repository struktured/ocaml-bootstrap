#!/usr/bin/env bash

arg0=$1
get_target() {
  local target_default=$HOME/local

  target=${arg0}
  if [ -z "${target}" ]; then
    target=${target_default}
  fi
  target_help="Specifies the target installation directory. Defaults to ${target_default}"
}


get_url() {

url="http://ftp.gnu.org/gnu/m4/m4-1.4.tar.gz"

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

  echo Compiling and installing m4...
  cd ${filename}
  ./configure --prefix=${target}
  make && make install
  cd ..

}

setup_env() {

  local m4_path=${target}/bin

  export PATH=$PATH:${m4_path}
  local path_string_cmt="# Add location of m4 to path"
  local path_string="export PATH=\$PATH:${m4_path}"
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
  fi

  if [ ! -z ${profile} ]; then 
    path_txt=`grep -o \"${m4_path}\" ${profile}`

    if [ -z "${path_txt}" ]; then
      echo "Adding \"${m4_path}\" to path in ${profile}" 
      echo ${path_string_cmt} >> ${profile}
      echo ${path_string} >> ${profile}
    fi
  fi
}

check_if_installed() {

res=`which m4`

if [ ! -z "${res}" ]; then
  echo m4 already installed at \"${res}\".
  exit 0
fi

}

run() {
  no_check_certificate_arg
  get_target
  get_url
  fetch_package
  preinstall_clean 
  decompress
  install
  setup_env
}

check_if_installed
run
