#!/bin/bash

if [ "$UID" -ne "0" ]
then
  echo "You must be root."
  exit 1
fi

# set up genome repo
wget -O - -q http://repo.gsc.wustl.edu/ubuntu/files/genome-center.asc | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/genome.list
deb http://repo.gsc.wustl.edu/ubuntu lucid main
deb http://repo.gsc.wustl.edu/ubuntu lucid-genome-development main
EOF
aptitude update
aptitude install -y git-core
aptitude install -y libur-perl
aptitude install -y libworkflow-perl
aptitude install -y libwebservice-solr-perl libcache-memcached-perl libtest-mockobject-perl bioperl libregexp-common-perl libmime-lite-perl libfile-grep-perl libfile-slurp-perl libinline-perl unzip libdatetime-perl
# refalign
aptitude install -y libfile-copy-recursive-perl

# get oracle-xe-universal_10.2.0.1-1.0_i386.deb
aptitude install -y libaio-dev libaio1

# gmt
#aptitude install -y libsort-naturally-perl libanyevent-perl libtest-class-perl libexception-class-perl libmail-sender-perl libguard-perl libcarp-assert-perl libdatetime-perl libfile-ncopy-perl libmail-sendmail-perl libpoe-perl libpoe-component-ikc-perl libtext-csv-perl libmethod-alias-perl libmoosex-types-perl libnamespace-autoclean-perl libmoosex-types-path-class-perl libstatistics-basic-perl libmath-basecalc-perl libgtk2-perl libtest-output-perl libmoosex-strictconstructor-perl liblog-log4perl-perl liblog-dispatch-perl libdbix-dbschema-perl libdbix-class-schema-loader-perl libjson-perl libfile-copy-recursive-perl libgtk2.0-dev libgtk2.0-common cups-client default-jdk pari-gp libgraphics-gnuplotif-perl

#aptitude install -y libtext-table-perl libemail-simple-perl libemail-valid-perl unzip weka

# while on virtualbox, try newer guest additions
#aptitude install -y virtualbox-ose-guest-utils

# modules to cpan
# FASTAParse

# modules that need manual install
# do we really need them?
# Math::Pari
# Inline::Java
# 1. Setup JAVA_HOME, then cpan Inline::Java may work
