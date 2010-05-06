#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More;
use File::Temp;
use File::Copy;
use File::Compare;

BEGIN {
    if (`uname -a` =~ /x86_64/){
        plan tests => 8;
    }
    else{
        plan skip_all => 'Must run on a 64 bit machine';
    }

    use_ok('Genome::Model::Tools::Maq::MapToBam');
}

my $root_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-MapToBam';
my $run_dir = '/gsc/var/cache/testsuite/running_testsuites';

my $tmp_dir  = File::Temp::tempdir(
    "MapToBAMDir_XXXXXX", 
    DIR     => $run_dir,
    CLEANUP => 1,
);

copy "$root_dir/test.map", $tmp_dir;
my $ref_list = Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fa.fai';
my $map_file = "$tmp_dir/test.map";
my $bam_file = "$tmp_dir/test.bam";
my $sam_file = $bam_file;
$sam_file =~ s/\.bam$/\.sam/;

my $to_bam = Genome::Model::Tools::Maq::MapToBam->create(
    map_file => $map_file,  
    ref_list => $ref_list,
    keep_sam => 1,
    fix_mate => 0,
    use_version => '0.7.1',
);

my $to_bam_bam_file = $to_bam->bam_file_path;
ok($to_bam_bam_file eq $bam_file, 'bam_file_path method return ok');

isa_ok($to_bam,'Genome::Model::Tools::Maq::MapToBam');
ok($to_bam->execute,'bam executed ok');

is(compare($sam_file, "$root_dir/test_short.sam"), 0, 'Sam file was created ok');
cmp_ok(compare($bam_file, "$root_dir/test_short.bam"), '==', 0, 'Bam file was created ok');

my $to_bam_fixmate = Genome::Model::Tools::Maq::MapToBam->create(
    map_file => $map_file,    
    ref_list => $ref_list,
    keep_sam => 1,
    fix_mate => 1,
    use_version => '0.7.1',
);

ok($to_bam_fixmate->execute,'bam fixmate executed ok');
is(compare($bam_file, "$root_dir/test_short.fix.bam"), 0, 'Bam file with mate fixed was created ok');

exit;

