#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::Sam::AlignmentComparator;
use Test::More;
use File::Compare;

if (`uname -a` =~ /x86_64/){
    plan tests => 9;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sam-AlignmentComparator';
my $input_bwa  = "$dir/bwa_aln.sorted.bam";
my $input_novo = "$dir/novotest.sorted.bam";
my $fai_file  = "$dir/all_sequences.fa.fai";

# step 1: test normal (2 files) case

my $out_dir = File::Temp->newdir();

my $cmd_1 = Genome::Model::Tools::Sam::AlignmentComparator->create(
    files_to_compare => [$input_bwa, $input_novo],
    fai_file         => $fai_file,
    output_dir       => $out_dir->dirname,
);

ok($cmd_1, "created command");
ok($cmd_1->execute, "executed");

my @outfiles = glob($out_dir->dirname."/*");

ok(scalar(@outfiles) == 2, "2 outputs created");
ok(-s $outfiles[0], 'input 1 nonempty');
ok(-s $outfiles[1], 'input 2 nonempty');

for my $f (@outfiles){
    unlink $f;
}

# step 2: test degenerate cases

open OLDERR, '>&STDERR' or die "Can't dup STDERR: $!";
open STDERR, '>/dev/null' or die "Can't redirect STDERR: $!";

my $cmd_2 = Genome::Model::Tools::Sam::AlignmentComparator->create(
    files_to_compare => [$input_bwa],
    fai_file         => $fai_file,
    output_dir       => $out_dir->dirname,
);

ok($cmd_2, "created command");
ok(!$cmd_2->execute, "1 input case failed as expected");

my $cmd_3 = Genome::Model::Tools::Sam::AlignmentComparator->create(
    files_to_compare => [$input_bwa,$input_novo],
    output_dir       => $out_dir->dirname,
);

ok($cmd_3, "created command");
ok(!$cmd_3->execute, "no FAI file case failed as expected");

open STDERR, ">&OLDERR" or die "Can't dup OLDERR: $!";
