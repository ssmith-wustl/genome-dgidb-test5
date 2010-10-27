#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More;
use File::Temp;
use File::Compare;

BEGIN {
    if (`uname -a` =~ /x86_64/){
        plan tests => 5;
    }
    else{
        plan skip_all => 'Must run on a 64 bit machine';
    }

    use_ok('Genome::Model::Tools::Sam::VarFilter');
}

my $root_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sam/VarFilter';
my $run_dir  = '/gsc/var/cache/testsuite/running_testsuites';

my $tmp_dir  = File::Temp::tempdir(
    "VarFilter_XXXXXX", 
    DIR     => $run_dir,
    CLEANUP => 1,
);

my $bam_file  = "$root_dir/test.bam";
my $ref_seq   = Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fasta';
my $ori_snp   = "$root_dir/test.bam.snp.varfilter";
my $ori_indel = "$root_dir/test.bam.indel.varfilter";
my $snp_out   = "$tmp_dir/snp.varfilter";
my $indel_out = "$tmp_dir/indel.varfilter";

my $filter = Genome::Model::Tools::Sam::VarFilter->create(
    bam_file     => $bam_file,                                                      
    ref_seq_file => $ref_seq,
    filtered_snp_out_file   => $snp_out,
    filtered_indel_out_file => $indel_out,
);

isa_ok($filter,'Genome::Model::Tools::Sam::VarFilter');
ok($filter->execute,'executed ok');

is(compare($ori_snp, $snp_out), 0, 'filtered SNP output is generated as expected');
is(compare($ori_indel, $indel_out), 0, 'filtered indel output is generated as expected');

exit;

