#!/gsc/bin/perl

use strict;
use warnings;
use above 'Genome';
use Test::More tests => 5;


my $input = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sample-NameConversion/test.in";
ok(-e $input);

my $output = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sample-NameConversion/test.out";
my $expected_output = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sample-NameConversion/expected.test.out";
ok(-e $expected_output);

my $conversion = Genome::Model::Tools::Sample::NameConversion->execute(input=>$input,output=>$output,short_to_long=>"1");
ok($conversion);

ok(-e $output);

my $diff = `diff $output $expected_output`;
ok($diff eq '', "output as expected");

print qq(done\n);

