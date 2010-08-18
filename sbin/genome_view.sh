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
  GENOME_DEV_MODE=1
  export GENOME_DEV_MODE
fi

  # using dev solr instance until hardware clones solr-dev -> solr
  GENOME_DEV_MODE=1
  export GENOME_DEV_MODE

## change the symlink to the real path
INC=`cd $INC; pwd -P`

## other options
PSGI=$INC/Genome/Model/Command/Services/WebApp/Main.psgi
PORT=3060
WORKERS=5
OPTIONS="-M Genome::Model::Command::Services::WebApp::FCGI::Patch --app $PSGI -s FCGI -E development -I $INC --port $PORT -M Genome::Model::Command::Services::WebApp::Core --nproc $WORKERS --keep-stderr 1 --manager Genome::Model::Command::Services::WebApp::FCGI::ProcManager"

# override perl5lib to be exactly what we want, no more
PERL5LIB=/gsc/scripts/lib/perl
export PERL5LIB

#if [ -e $HOME/perl5 ]
#then
#    eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)
#fi

exec /gsc/bin/plackup $OPTIONS >>/var/log/kom/genome_view.log 2>&1 
