#!/bin/bash
SCRIPT_PATH=`readlink -f $0`
DIR_PATH=`dirname $SCRIPT_PATH`

if [ "$UID" -eq "0" ]
then
  echo "This must be run as a regular user"
  exit 1
fi

cp $DIR_PATH/tnsnames.org $HOME/

echo "export PERL5LIB=$HOME/genome/lib/perl:\$PERL5LIB" >> $HOME/.bashrc
echo "export PATH=$HOME/genome/bin:\$PATH" >> $HOME/.bashrc
echo "export TNS_ADMIN=$HOME" >> $HOME/.bashrc
echo "export ORACLE_HOME=/opt/oracle-instantclient" >> $HOME/.bashrc
