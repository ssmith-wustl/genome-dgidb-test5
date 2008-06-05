#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::FastqChopper;
use Test::More;
plan "skip_all";

my $file = "/gscuser/charris/svn/pm2/Genome/Model/Tools/test.fastq";
my $total = lines($file);

my $size = 5;
my $chopper = Genome::Model::Tools::FastqChopper->create(
                                                         fastq_file => $file,
                                                         size => $size,
                                                        );
ok($chopper->execute,'chopper execution');

my $sub_fastq_files_ref = $chopper->sub_fastq_files;
my @sub_fastq_files = @$sub_fastq_files_ref;
my $expected = (($total/4)/$size);
is(scalar(@sub_fastq_files),$expected,'file count');

for my $sub_fastq_file (@sub_fastq_files) {
    my $lines = lines($sub_fastq_file);
    is($lines,($size *4),'line count');
}

exit;


sub lines {
    my $file = shift;
    my $out = `wc -l $file`;
    my @out = split /\s+/, $out;
    return $out[0];
}
