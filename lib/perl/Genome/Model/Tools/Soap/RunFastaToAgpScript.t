#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More;
require File::Compare;

use_ok('Genome::Model::Tools::Soap::RunFastaToAgpScript');

#check test data dir and files
my $version = 'v0';
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Soap/RunFastaToAgpScript_'.$version;
ok (-d $data_dir, "Data dir exists") or die;

#check test input/output files
ok (-s $data_dir.'/TEST.scafSeq', "TEST.scafSeq file exists in data dir") or die;
my @out_files = qw/ SRS012663_PGA.scaffolds.fa SRS012663_PGA.contigs.fa SRS012663_PGA.agp /;
foreach (@out_files) {
    ok (-s $data_dir."/$_", "Test $_ file exists") or die;
}

#create tmp test dir
my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
ok (-d $temp_dir, "Temp test dir created") or die;

#copy input files over to temp dir
ok (File::Copy::copy ($data_dir.'/TEST.scafSeq', $temp_dir), "Copied TEST.scafSeq to temp test dir") or die;
ok (-s $temp_dir.'/TEST.scafSeq', "Temp test dir TEST.scafSeq file exists") or die;

#create/execute
my $c = Genome::Model::Tools::Soap::RunFastaToAgpScript->create (
    scaffold_fasta_file => $temp_dir.'/TEST.scafSeq',
    scaffold_size_cutoff => 100,
    output_dir => $temp_dir,
    output_file_prefix => 'SRS012663_PGA',
    version => '9.27.10',
    );

ok ($c, "Created fasta-to-agp tool") or die;
ok ($c->execute, "Successfully executed fasta-to-agp tool") or die;

#compare output files .. these should match
foreach (qw/ SRS012663_PGA.scaffolds.fa SRS012663_PGA.contigs.fa /) {
    ok (-s $temp_dir."/$_", "Created $_ file") or die;
    ok (File::Compare::compare($temp_dir."/$_", $data_dir."/$_") == 0, "$_ files match") or die;
}

#this has a unique file header than won't match
ok(-s $temp_dir.'/SRS012663_PGA.agp', "Created SRS012663_PGA.agp file") or die;
ok(File::Compare::compare($temp_dir.'/SRS012663_PGA.agp', $data_dir.'/SRS012663_PGA.agp') == 1, "Found 1 difference in SRS012663_PGA.agp files") or die;

done_testing;

exit;
