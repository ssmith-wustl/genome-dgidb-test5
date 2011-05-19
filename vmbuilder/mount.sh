#!/bin/bash

# This will mount VBox shared folders.
# It assumes the following names have been added to VBox:
#   gscmnt
#   var
#   lsf

if [ "$UID" -ne "0" ]
then
  echo "You must be root."
  exit 1
fi

mkdir /gscmnt
mount -t vboxsf gscmnt /gscmnt -o uid=1000,gid=100,umask=007

mkdir -p /gsc/var
mount -t vboxsf var /gsc/var -o uid=1000,gid=100,umask=007

mkdir -p /usr/local/lsf
mount -t vboxsf lsf /usr/local/lsf -o uid=1000,gid=100,umask=007
