#!/bin/sh

str=""
for var in "$@" 
do
  fixed=`cygpath -w ${var}`
  str="${str} ${fixed}" 
done

aspcud ${str}
