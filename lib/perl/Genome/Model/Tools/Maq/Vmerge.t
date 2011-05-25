#!/usr/bin/env perl

use strict;
use warnings;
use Genome;

use File::Temp;
use File::Compare;

use Test::More;

if (`uname -a` =~ /x86_64/){
    plan tests => 6;
}
else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my $expected_results = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Vmerge/myresult_real';

my (undef,$pipe_path) = File::Temp::tempfile;

my $test_results = $pipe_path .'.virtual';

ok(unlink($pipe_path),"delete existing temporary file $pipe_path");

my $vmerge_cmd = "gmt maq vmerge --maplist /gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Vmerge/all.maplist --pipe $pipe_path &";
my $vmerge_rv = system($vmerge_cmd);
ok(!$vmerge_rv,"$vmerge_cmd executed successfully");

while (!-e $pipe_path) {
    sleep 1;
}

my $cmd = "/gsc/pkg/bio/maq/maq-0.6.8_x86_64-linux/maq mapview $pipe_path > $test_results";
my $rv = system($cmd);
ok(!$rv,"$cmd executed successfully");
ok(!compare($test_results,$expected_results),'test result matches expected');

#Clean up
SKIP: {
    skip 'unnecessary to unlink file if it does not exist', 1 if !-e $pipe_path;
    ok(unlink($pipe_path),"remove pipe $pipe_path");
}

ok(unlink($test_results),"remove test results $test_results");

exit;
