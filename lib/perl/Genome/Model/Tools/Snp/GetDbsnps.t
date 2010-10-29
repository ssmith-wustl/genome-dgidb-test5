#!/gsc/bin/perl

use strict;
use warnings;
use above "Genome";

use Test::More tests => 5;

my $chromosome = "10";
my $start = 126008345;
my $stop = 126010576;
my $organism = "human"; # or mouse


my $output_dir = Genome::Utility::FileSystem->create_temp_directory('Genome-Model-Tools-Snp-GetDbsnps');
my $out = "$output_dir/GetDbsnps.testout";
my $dbsnpout ="$output_dir/GetDbsnps.testout.dbsnp.gff";
if ($dbsnpout && -e $dbsnpout) {`rm $dbsnpout`;}
my $expected_output = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Snp-GetDbsnps/GetDbsnps.expectedout.dbsnp.gff";

#ok(-e $expected_output);

my $dbsnps = Genome::Model::Tools::Snp::GetDbsnps->create(chromosome=>$chromosome,start=>$start,stop=>$stop,organism=>$organism,gff=>1,out=>$out);
ok($dbsnps);

ok($dbsnps->execute());
ok(-e $dbsnpout);
ok(-e $expected_output);

my $diff = `diff $dbsnpout $expected_output`;
ok($diff eq '', "output as expected");

