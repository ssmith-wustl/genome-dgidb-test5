#!/gsc/bin/perl

use strict;
use warnings;

use Test::More;
use File::Compare;

use above 'Genome';

if (`uname -a` =~ /x86_64/){
    plan tests => 1;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

use_ok('Genome::Model::Tools::Sam::BamToSam');

my $tmp_dir = Genome::Utility::FileSystem->create_temp_directory('Genome-Model-Tools-Sam-BamToFastq-'. $ENV{USER});
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sam-BamToSam';
my $bam_file = $data_dir .'/test.bam';

