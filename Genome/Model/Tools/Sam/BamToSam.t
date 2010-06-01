#!/gsc/bin/perl

use strict;
use warnings;

use Test::More;
use File::Compare;

use above 'Genome';

if (`uname -a` =~ /x86_64/){
    plan tests => 3;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

use_ok('Genome::Model::Tools::Sam::BamToSam');

my $tmp_dir = Genome::Utility::FileSystem->create_temp_directory('Genome-Model-Tools-Sam-BamToFastq-'. $ENV{USER});
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sam-BamToSam';
my $bam_file = $data_dir .'/test.bam';

my $result = Genome::Model::Tools::Sam::BamToSam->execute( bam_file => $bam_file);


ok(-e $data_dir."/test.sam","Found output file, properly named.");
ok($result,"Tool exited properly.");

if(-e $data_dir."/test.sam") {
    unlink($data_dir."/test.sam");
}
