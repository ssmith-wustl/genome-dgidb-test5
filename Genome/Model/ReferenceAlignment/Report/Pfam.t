#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 8;
use above "Genome";
use File::Slurp;
use File::Temp;
use File::Basename;

my $Bin = File::Temp::tempdir(CLEANUP => 1);

BEGIN {
    use_ok("Genome::Model::ReferenceAlignment::Report::Pfam");
}

my $build_id = 93293206;
my $build = Genome::Model::Build->get(build_id => $build_id);
ok($build, "got a build");

my ($id, $name) = ($build_id,'Pfam');

my $model_id = 2733662090; #2661729970;
#$report->_process_coding_transcript_file($Bin . '/Pfam.t.dat');

my $p = Genome::Model::ReferenceAlignment::Report::Pfam->create(
                                            build_id => $build_id,
                                            #model_id => $model_id,
                                            test_no_load => 1
                                           );

# is this a "Genome::Model::ReferenceAlignment::Report::Pfam" object?
is(ref($p), 'Genome::Model::ReferenceAlignment::Report::Pfam');

my $snpstestfile = "snpfiletest.pfam.dat";
my $testoutput = "testoutput.snps.dat";
my $readonly_testfile = "readonly.snps.dat";

my $test_dir = File::Basename::dirname(__FILE__); 
my @lines = read_file($test_dir."/".$snpstestfile);

# test creating the snps dat list file
ok($p->_create_snpsdat_file(\@lines, $Bin."/".$testoutput), 'can write out file');
unlink $testoutput;

write_file($Bin."/".$readonly_testfile, ('blah'));
chmod 0444, $Bin."/".$readonly_testfile;
ok($p->_create_snpsdat_file(\@lines, $Bin."/".$readonly_testfile) eq 0, 'test for failure on writing file out');
chmod 0644, $Bin."/".$readonly_testfile;
unlink $Bin."/".$readonly_testfile;

#$p = undef;
my $runiprscan = undef;
if(exists($ENV{RUNIPRSCAN}))
{
    $runiprscan = 1;
}

SKIP: {
    skip "need to set environment variable to run iprscan", 1 unless $runiprscan ;
# test checking the transcripts/getting the peps/prots.
    $p = Genome::Model::ReferenceAlignment::Report::Pfam->create(
                                          build_id      => $build_id,
                                         #model_id     => $model_id,
                                         name         => 'Pfam',
                                         test_no_load => 1,
                                        );
    my $coding_ts_file = "pfam_coding_transcript_data.dat";
    ok($p->_process_coding_transcript_file($Bin."/".$coding_ts_file),'processing coding transcript annotation file');

    foreach my $file ((".snps.dat",".gff",".pep.fasta",".transcript_names"))
    {
        unlink $Bin."/".$coding_ts_file . $file;
    }

} # end skip
#$p = undef;

#$p = Genome::Model::ReferenceAlignment::Report::Pfam->create(
#                                        build_id => $build_id,
#                                         #model_id     => $model_id,
#                                         name         => 'Pfam',
#                                         test_no_load => 1,
#                                        );

my $test_report = "pfam_test_report.csv";
my $test_snpsdat_report = "pfam_test_report.snps.dat";
my $report_buffer = undef;
$report_buffer = $p->_run_report($Bin."/".$test_snpsdat_report );
print Data::Dumper::Dumper(\$report_buffer),"\n";
ok(defined($report_buffer),'test running the report');

# should check the output... cant do this now
#my @comparison1 = read_file($Bin."/"."pfam_test_report.comparison");
#my @comparison2 = read_file($Bin."/".$test_report);
#is_deeply(\@comparison2,\@comparison1, 'report contents match');
#unlink $test_report;

#$p = undef;
# test full run of the generate_report_detail method.

#$p = Genome::Model::ReferenceAlignment::Report::Pfam->create(
#                                        build_id => $build_id,
#                                         #model_id     => $model_id,
#                                         name         => 'Pfam',
#                                         test_no_load => 1,
#                                        );

SKIP: {
    skip "need to set environment variable to run iprscan", 1 unless $runiprscan ;
ok($p->generate_report_detail(report_detail => $Bin."/"."full_report_test.csv"),'run a full report via generate_report_detail()');
unlink $Bin."/"."full_report_test.csv";
} # end skip
