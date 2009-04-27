#!/gsc/bin/perl

use strict;
use warnings;

use File::Path;
use Test::More tests => 2;

use above 'Genome';

my $build_id = '96791303';

my $build_status = Genome::Model::Command::Build::Status->create(build_id=>$build_id);
ok($build_status);
my $rv = $build_status->execute;
#print "\n\n";
#print $rv;
#print "\n\n";
my $length_test = 0;
if (length($rv) > 7000 ) {
    $length_test = 1 ;
} 
is($length_test,1,'Testing success: Expecting a long XML string (>7000 chars). Got a string of length: '.length($rv));
