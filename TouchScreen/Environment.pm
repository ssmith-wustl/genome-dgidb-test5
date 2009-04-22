package TouchScreen::Environment;

# this defines environmental parameters to be tested by the test touchscreen

# standard test touchscreen stuff:
use strict;
use warnings;
use lib "/gsc/scripts/test/touchscreen";

# oracle environment variables

$ENV{ORACLE_BASE} = "/gsc/pkg/oracle";
$ENV{ORACLE_HOME} = "$ENV{ORACLE_BASE}/10gR2/db_1";
    
my %ENVIRONMENT = 
    (
     "TNS_ADMIN" => "$ENV{ORACLE_HOME}/network/admin",
     "TWO_TASK" => "gscprod",
     "ORACLE_PATH" => "$ENV{ORACLE_HOME}/bin:ENV{PATH}",
     "PATH" => "$ENV{PATH}:$ENV{ORACLE_HOME}/bin",
     "LD_LIBRARY_PATH" => "$ENV{LD_LIBRARY_PATH}:$ENV{ORACLE_HOME}/lib",
    );


foreach my $envkey (keys %ENVIRONMENT){
    $ENV{$envkey} = $ENVIRONMENT{$envkey};
}

use lib "/gsc/lib/perl/test/lib/perl5/5.8.7";
use lib "/gsc/lib/perl/test/lib/perl5/site_perl/5.8.7";

1;
