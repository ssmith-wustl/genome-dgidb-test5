#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 3;

use_ok ('Genome::Model::Command::Build::CombineVariants::ConfirmQueues::ConfirmQueuesForAssembly');
ok(my $dump = Genome::Model::Command::Build::CombineVariants::ConfirmQueues::ConfirmQueuesForAssembly->create(), 
    'Created ConfirmQueuesForAssembly object');
isa_ok($dump, 'Genome::Model::Command::Build::CombineVariants::ConfirmQueues::ConfirmQueuesForAssembly'); 

#TODO how do we test this better?
