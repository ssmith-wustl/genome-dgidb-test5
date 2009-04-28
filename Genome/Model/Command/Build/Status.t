#!/gsc/bin/perl

use strict;
use warnings;

use File::Path;
use Test::More tests => 5;

use above 'Genome';

my $build_id = '96791303';

my $build_status = Genome::Model::Command::Build::Status->create(build_id=>$build_id, display_output=>0);
ok($build_status);
my $rv = $build_status->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);
my $length_test = 0;
my $xml = $build_status->xml();
if (length($xml) > 7000 ) {
    $length_test = 1 ;
} 
is($length_test,1,'Testing success: Expecting a long XML string (>7000 chars). Got a string of length: '.length($xml));

my $build_status2 = Genome::Model::Command::Build::Status->create(build_id=>$build_id, display_output=>0,use_lsf_file=>1);
ok($build_status2);
my $rv2 = $build_status2->execute;
is($rv2, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv2);
