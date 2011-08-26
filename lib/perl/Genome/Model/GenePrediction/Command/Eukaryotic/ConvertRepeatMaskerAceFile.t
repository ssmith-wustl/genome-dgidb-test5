#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok('Genome::Model::GenePrediction::Command::Eukaryotic::ConvertRepeatMaskerAceFile') or die;

my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-GenePrediction-Eukaryotic/repeat_masker/';
ok(-d $test_data_dir, "test data dir exists at $test_data_dir") or die;

my $test_output_dir = '/gsc/var/cache/testsuite/running_testsuites/';
ok(-d $test_output_dir, "test output dir exists at $test_output_dir") or die;

my $fasta = $test_data_dir . 'fasta_0';
ok(-e $fasta, "fasta file exists at $fasta") or die;

my $ace_file = $test_data_dir . 'test.fasta.repeat_masker.ace';
ok(-e $ace_file, "ace file exists at $ace_file") or die;

my $gff_file = $test_data_dir . 'test.fasta.repeat_masker.gff';
ok(-e $gff_file, "gff file exists at $gff_file") or die;

my $expected_output = $test_data_dir . 'repeat_masker.ace.converted.expected';
ok(-e $expected_output, "expected output exists at $expected_output") or die;

my $output_file_fh = File::Temp->new(
    DIR => $test_output_dir,
    TEMPLATE => 'repeat_masker_converted_ace_XXXXXX',
);
my $output_file = $output_file_fh->filename;
$output_file_fh->close;

my $object = Genome::Model::GenePrediction::Command::Eukaryotic::ConvertRepeatMaskerAceFile->create(
    fasta_file => $fasta,
    ace_file => $ace_file,
    gff_file => $gff_file,
    converted_ace_file => $output_file,
);
ok($object, "successfully created command object") or die;

ok($object->execute, "successfully executed command object") or die;

ok(-e $output_file and -s $output_file, "output file $output_file exists and has size");

my $expected_md5 = Genome::Sys->md5sum($expected_output);
my $actual_md5 = Genome::Sys->md5sum($output_file);
ok($expected_md5 eq $actual_md5, "actual output matches expected output");

done_testing();


