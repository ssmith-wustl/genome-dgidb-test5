#!/gsc/bin/perl

use strict;
use warnings;
use above "Genome";

use Test::More tests => 6;


my $list = "/gscmnt/sata420/info/testsuite_data/Genome-Model-Tools-Annotate-GeneRegions/coordinates_list";
ok(-f $list);

my $output = "/gscmnt/sata420/info/testsuite_data/Genome-Model-Tools-Annotate-GeneRegions/coordinates_list_output";
if (-f $output) {system qq(rm $output);}

my $regions = Genome::Model::Tools::Annotate::GeneRegions->create(list=>$list, mode => 'coordinates', output => $output);
ok($regions);

ok($regions->execute());
ok(-f $output);
my $expected_output = "/gscmnt/sata420/info/testsuite_data/Genome-Model-Tools-Annotate-GeneRegions/expected_output";
ok(-f $expected_output);

my $diff = `diff $output $expected_output`;
ok($diff eq '', "output as expected");


