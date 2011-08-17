#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 7;

use Genome::Sys;

my $tmp = Genome::Sys->create_temp_directory();
if (-e $tmp .'/Quality/report.xml') {
    unlink $tmp .'/Quality/report.xml';
}

my $base_dir         = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Solexa-Report-Quality/';
my $gerald_directory = $base_dir .'/test_sample_name';
my $ori_report_xml   = $base_dir .'/report.xml';

my $instrument_data = Genome::InstrumentData::Solexa->create_mock(
                                                                  id => '-123456',
                                                                  sequencing_platform => 'solexa',
                                                                  sample_name => 'test_sample_name',
                                                                  library_name => 'test_library_name',
                                                                  library_id => '-1233445',
                                                                  run_name => 'test_run_name',
                                                                  subset_name => 4,
                                                                  lane => 4,
                                                                  run_type => 'Paired End Read 2',
                                                                  is_paired_end => 1,
                                                                  #gerald_directory => $gerald_directory,
                                                                  bam_path => $base_dir.'/test_run_name.bam',
                                                              );
isa_ok($instrument_data,'Genome::InstrumentData::Solexa');

#comment out following lines for changed codes in G::I::S::resolve_fastq_filenames
#$instrument_data->set_always('dump_illumina_fastq_archive',$instrument_data->gerald_directory);
#$instrument_data->mock('read1_fastq_name', \&Genome::InstrumentData::Solexa::read1_fastq_name);
#$instrument_data->mock('read2_fastq_name', \&Genome::InstrumentData::Solexa::read2_fastq_name);

my @fastq_files = map{$gerald_directory.'/s_'.$instrument_data->lane.'_'.$_.'_sequence.txt'}qw(1 2);
$instrument_data->set_always('resolve_fastq_filenames',\@fastq_files);

my $r = Genome::InstrumentData::Solexa::Report::Quality->create(
    instrument_data_id => $instrument_data->id,
);
ok($r, "created a new report");

my $v = $r->generate_report;
ok($v, "generation worked");

my $result = $v->save($tmp);
ok($result, "saved to $tmp");

my $name = $r->name;
$name =~ s/ /_/g;

ok(-d "$tmp/$name", "report directory $tmp/$name is present");
ok(-e "$tmp/$name/report.xml", 'xml report is present');

my @diff = `diff "$tmp/$name/report.xml" $ori_report_xml`;
is(scalar @diff, 4, 'report.xml is created as expected'); #Only time stamp is different

