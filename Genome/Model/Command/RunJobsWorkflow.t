#!/gsc/bin/perl

use strict;
use warnings;

use File::Temp;
use Test::More tests => 1;
use IO::Socket;
use IO::Select;

use above "Genome";

require_ok("Genome::Model::Command::RunJobsWorkflow");
#require_ok("Genome::Model::Command::AddReads");

my $model_id = 2745528681;
my $read_set_id = 2338813645;

#my $arcmd = Genome::Model::Command::AddReads->create(
#    model_id => $model_id,
#    read_set_id => $read_set_id
#);

#$arcmd->execute();



