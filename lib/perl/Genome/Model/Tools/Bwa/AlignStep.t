#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More;

if (`uname -a` =~ /x86_64/){
    plan tests => 9;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

use_ok('Genome::Model::Tools::Bwa::AlignStep');

my $version = Genome::Model::Tools::Bwa->default_bwa_version;

print "Bwa version on test is $version\n";

my $ref_seq = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Bwa-AlignReads/reference-sequence/all_sequences.fa";

my $aln_dir = File::Temp::tempdir(CLEANUP=>1);

my $aln_input_1 = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Bwa-AlignReads/single-solexa/s_3_sequence.txt";

my $cmd = Genome::Model::Tools::Bwa::AlignStep->create(aligner_version=>$version,
                                                       alignments_dir=>$aln_dir,
                                                       query_input=>$aln_input_1,
                                                       reference_fasta_path=>$ref_seq,
                                                       bwa_aln_params=>'');

ok($cmd, "created Genome::Model::Tools::Bwa::AlignStep");
ok($cmd->execute, "executed");

ok($cmd->fastq_file, "has an fastq file");
ok((-f $cmd->fastq_file), "fastq file is where it said it would be");

ok($cmd->sai_file, "has an sai file");
ok((-f $cmd->sai_file), "sai file is where it said it would be");

ok($cmd->output_file, "has an output file");
ok((-f $cmd->output_file), "output file is where it said it would be");
