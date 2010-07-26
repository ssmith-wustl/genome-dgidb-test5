#!/gsc/bin/bash
#
# This script is used by /etc/init.d/genome_view on imp and aims-dev
# to start the fastcgi daemon.  It is here (vs the init script) so apipe 
# can update it to change options.
#

hostname=`hostname -s`

INC=/gsc/scripts/opt/genome-webapp/lib/perl

# TODO make this less dependent on the real hostname, check aims-dev cname?
if [ $hostname == 'vm45' ]
then
  INC=/gsc/scripts/opt/genome-webapp-dev/lib/perl
fi

## change the symlink to the real path
INC=`cd $INC; pwd -P`

## other options
PSGI=$INC/Genome/Model/Command/Services/WebApp/Main.psgi
PORT=3060
WORKERS=5
OPTIONS="--app $PSGI -s FCGI -E development -I $INC -M Genome::Model::Command::Services::WebApp::Core --port $PORT --nproc $WORKERS --keep-stderr 1 --manager Genome::Model::Command::Services::WebApp::FCGI::ProcManager"

# override perl5lib to be exactly what we want, no more
PERL5LIB=/gsc/scripts/lib/perl
export PERL5LIB

exec /gsc/bin/plackup $OPTIONS
