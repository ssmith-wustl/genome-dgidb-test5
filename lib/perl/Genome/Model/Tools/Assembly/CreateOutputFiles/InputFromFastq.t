#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

use Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq;

my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

my $test_fastq_file = $data_dir.'/test.fastq';
ok(-s $test_fastq_file, "Found test contigs.fa file");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
#copy input file
ok(File::Copy::copy($test_fastq_file, $temp_dir),"Copied input contigs file");

my $temp_fastq = $temp_dir.'/test.fastq';
ok(-s $temp_fastq, "New temp fastq file exists");

#make edit_dir in temp_dir
mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir.'/edit_dir', "Made edit_dir in temp test_dir");

my $ec = system("chdir $temp_dir; gmt assembly create-output-files input-from-fastq --directory $temp_dir --fastq-file $temp_fastq");
ok($ec == 0, "Command ran successfully");

#test input fasta file
my $test_fasta_file = $data_dir.'/edit_dir/test.fasta.gz';
ok(-s $test_fasta_file, "Test.fasta.gz file exists");
#test input qual file
my $test_qual_file = $data_dir.'/edit_dir/test.fasta.qual.gz';
ok(-s $test_qual_file, "Test.fasta.qual.gz file exists");

#new input fasta file
my $new_fasta_file = $temp_dir.'/edit_dir/test.fasta.gz';
ok(-s $new_fasta_file, "New test.fasta.gz file exists");
#new input qual file
my $new_qual_file = $temp_dir.'/edit_dir/test.fasta.qual.gz';
ok(-s $new_qual_file, "New test.fasta.qual.gz file exists");

#diff
#TODO - should unzip and do a diff
done_testing();

exit;
