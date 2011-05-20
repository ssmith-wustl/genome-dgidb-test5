#!/gsc/bin/bash
#
# This script is used by /etc/init.d/genome_view on imp and aims-dev
# to start the fastcgi daemon.  It is here (vs the init script) so apipe 
# can update it to change options.
#

# apipe-dev currently has an /etc/init.d/genome_view_dev which executes /gsc/scripts/bin/genome_view_dev (this file)

hostname=`hostname -s`

INC="/gscuser/jlolofie/dev/git/genome/lib/perl"
UR="/gsc/scripts/opt/genome/current/pipeline/lib/perl"
WORKFLOW="/gsc/scripts/opt/genome/current/pipeline/lib/perl"


GENOME_DEV_MODE=1
export GENOME_DEV_MODE

## change the symlink to the real path
INC=`cd $INC; pwd -P`

## this must be the same as /etc/init.d/genome_view
PIDFILE="/var/run/kom_fastcgi/genome_view.pid"

if test ! -w $PIDFILE
then
    rm -f $PIDFILE
fi
echo $$ >$PIDFILE

LOGFILE=/var/log/kom/genome_view.log

## other options
PSGI=$INC/Genome/Model/Command/Services/WebApp/Main.psgi
PORT=3060
WORKERS=20
OPTIONS="-M Genome::Model::Command::Services::WebApp::FCGI::Patch --app $PSGI --server FCGI -E development -I $INC -I $UR -I $WORKFLOW --port $PORT -M Genome::Model::Command::Services::WebApp::Core --nproc $WORKERS --keep-stderr 1 --manager Genome::Model::Command::Services::WebApp::FCGI::ProcManager --pid $PIDFILE"

# override perl5lib to be exactly what we want, no more
PERL5LIB=/gsc/scripts/lib/perl
export PERL5LIB

exec /gsc/bin/plackup $OPTIONS >>$LOGFILE 2>&1
