#!/usr/bin/env perl

use strict;
use warnings;

use File::Path;
use File::Temp;
use Test::More skip_all => "obsolete workflow";
use above 'Genome';

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    plan tests => 2;
}


#my $tmpdir = File::Temp::tempdir('AlignMetagenomesXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 0);
#my $tmpfile_snp = File::Temp->new( TEMPLATE=>'algin_metagenomes_outputXXXXX', DIR=>$tmpdir, UNLINK=>0, SUFFIX=>'.txt'  );
#my $output_snp_file = $tmpfile_snp->filename;
#my $tmpfile_indel = File::Temp->new( TEMPLATE=>'somatic_outputXXXXX', DIR=>$tmpdir, UNLINK=>0, SUFFIX=>'.txt'  );
#my $output_indel_file = $tmpfile_indel->filename;

#use_ok('Genome::Model::Tools::HmpShotgun::AlignMetagenomes');
my $ref_seq_file = "/gscmnt/sata413/research/kwylie/references/refseq_metagenome1/all_sequences.fa";
my $dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-MetagenomicCompositionShotgun-Align";
my $r1 = "$dir/1_sequence.txt";
my $r2 = "$dir/2_sequence.txt";
my $reads_file = "$r1\|$r2";
my $working_dir = "$dir/bwa_results";

my $aligner = Genome::Model::Tools::Bwa::AlignReads->create(dna_type=>'dna', 
                                                            ref_seq_file=>$ref_seq_file,
                                                            files_to_align_path=>$reads_file,
                                                            sam_only=>1,
                                                            aligner_output_file=>$working_dir."/aligner.out",
                 					    unaligned_reads_file=>$working_dir."/unaligned.txt",
    							    alignment_file=>$working_dir."/aligned.sam",
                                                            temp_directory=>$working_dir,
                                                            read_group_tag=>"2",
                                                            );
ok($aligner, 'aligner command created');
my $rv = $aligner->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);
