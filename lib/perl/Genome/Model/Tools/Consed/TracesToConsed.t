#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 12;

use_ok('Genome::Model::Tools::Consed::TracesToConsed');
my $base_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed";
ok (-s $base_dir , "base-dir exists");
my $trace_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/chromat_dir";
ok (-s $trace_dir , "trace-dir exists");

my $chromosome = "10";
my $start = 126009345;
my $stop = 126009576;
my $project_details = "11+11-INS";
my $extend_ref = 1000;

#####Build an ace file for manual review

my $project = "$chromosome\_$start";
my $project_dir = "$base_dir/$project";
if (-s $project_dir) {system qq(rm -rf $project_dir);}

#####my $ConsedTracesToConsed = Genome::Model::Tools::Consed::TracesToConsed->create(chromosome=>$chromosome,start=>$start,stop=>$stop,base_dir=>$base_dir,trace_dir=>$trace_dir,project_details=>$project_details,extend_ref=>"1");
#####ok ($ConsedTracesToConsed);
#####ok ($ConsedTracesToConsed->execute());

system qq(gmt consed traces-to-consed --chromosome $chromosome --start $start --stop $stop --base-dir $base_dir --trace-dir $trace_dir --project-details $project_details --extend-ref $extend_ref);

my $ace = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/$project/edit_dir/$project.ace.1";
ok (-s $ace ,"$project.ace.1 successfully produced");

my $ace_checker = Genome::Utility::AceSupportQA->create();
ok($ace_checker, "created ace checker");
ok($ace_checker->ace_support_qa($ace), "$project.ace.1 passes the ace checker");
ok($ace_checker->contig_count != 1, "More than one contig found as expected");

my $assembly_traces = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/10_126008345_126010576.traces.fof";
ok (-s $assembly_traces , "assembly-traces exists");

#####Build an ace file for 
$start = 126008345;
$stop = 126010576;

$project = "$chromosome\_$start\_$stop";
#$project = "NEWTEST";

$project_dir = "$base_dir/$project";
if (-s $project_dir) {system qq(rm -rf $project_dir);}

system qq(gmt consed traces-to-consed --chromosome $chromosome --start $start --stop $stop --base-dir $base_dir --trace-dir $trace_dir --restrict-contigs --link-traces --project $project --assembly-traces $assembly_traces);
#print qq(gmt consed traces-to-consed --chromosome $chromosome --start $start --stop $stop --base-dir $base_dir --trace-dir $trace_dir --restrict-contigs --link-traces --project $project --assembly-traces $assembly_traces);

#####undef($ConsedTracesToConsed);

##### $ConsedTracesToConsed = Genome::Model::Tools::Consed::TracesToConsed->create(chromosome=>$chromosome, start=>$start, stop=>$stop, base_dir=>$base_dir, trace_dir=>$trace_dir, project=> $project , restrict_contigs=>"1", link_traces=>"1", assembly_traces=>$assembly_traces);
#####ok ($ConsedTracesToConsed, "ConsedTracesToConsed");
#####$ConsedTracesToConsed->execute();
   # exit;
$ace = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-TracesToConsed/$project/edit_dir/$project.ace.1";
ok (-s $ace ,"$project.ace.1 successfully produced");

$ace_checker = Genome::Utility::AceSupportQA->create();
ok($ace_checker, "created ace checker");
ok($ace_checker->ace_support_qa($ace), "$project.ace.1 passes the ace checker");
ok($ace_checker->contig_count == 1, "Exactly one contig found as expected");
