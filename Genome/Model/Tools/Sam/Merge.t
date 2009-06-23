#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::Sam::Merge;
use Test::More;
#tests => 1;

if (`uname -a` =~ /x86_64/){
    plan tests => 8;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my $input_normal = '/gsc/var/cache/testsuite/data/Genome-Tools-Sam-Merge/normal.tiny.bam';
my $input_tumor = '/gsc/var/cache/testsuite/data/Genome-Tools-Sam-Merge/tumor.tiny.bam';

# step 1: test 1 file case

my $out_1_file = File::Temp->new(SUFFIX => ".bam" );

my $cmd_1 = Genome::Model::Tools::Sam::Merge->create(files_to_merge=>[$input_normal],
                                                     merged_file=>$out_1_file->filename);

ok($cmd_1, "created command");
ok($cmd_1->execute, "executed");
ok(-s $out_1_file->filename, "output file is nonzero");

# step 1: test >1 input file case

my $out_2_file = File::Temp->new(SUFFIX => ".bam" );

my $cmd_2 = Genome::Model::Tools::Sam::Merge->create(files_to_merge=>[$input_normal, $input_tumor],
                                                     merged_file=>$out_2_file->filename);

ok($cmd_2, "created command");
ok($cmd_2->execute, "executed");
ok(-s $out_2_file->filename, "output file is nonzero");



