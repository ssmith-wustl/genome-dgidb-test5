#!/gsc/bin/perl
#
# FIXME  test existed. Write some, please.
#
# 2010jul30 ebelter 
#  added tests for dumping fasta, qual and fastq
#

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Genome::Config;
use Genome::Utility::TestBase;
use Test::More;

like(Genome::Config->arch_os, qr/x86_64/, 'On 64 bit machine') or die;

use_ok('Genome::InstrumentData::454') or die;

my $dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-454';
my $id = 2852582718;
my $id454 = Genome::Utility::TestBase->create_mock_object (
    # This is info from a real 454 index region
    class => 'Genome::InstrumentData::454',
    id => $id,
    seq_id => $id,
    sequencing_platform => '454',
    region_id => 2848985861,
    region_number => 2,
    sample_name => 'H_MA-.0034.01-89515740',
    library_name => 'H_MA-.0034.01-89515740PCRfwdgreva',
    run_name => 'R_2010_01_09_11_08_12_FLX08080418_Administrator_100737113',
    index_sequence => 'AACGGAGTC',
    total_reads => 6437,
    sff_file => "$dir/$id.sff",
) or die "Unable to create mock 454 inst data";
$id454->set_always('sff_file', "$dir/$id.sff");
Genome::Utility::TestBase->mock_methods(
    $id454,
    (qw/
        dump_sanger_fastq_files 
        dump_fasta_file dump_qual_file _run_sffinfo
        /)
) or die "Can't mock 454 methods";


# Fasta, Qual, Fastq files and names
my %types_methods = (
    fasta => 'dump_fasta_file',
    qual => 'dump_qual_file',
    fastq => 'dump_sanger_fastq_files',
);
for my $type ( keys %types_methods ) {
    my $method = $types_methods{$type};
    my ($file) = $id454->$method;
    ok($file, "dumped $type file");
    like($file, qr/$id(-output)?.$type$/, "$type file name matches: $file");
    my $example_file = "$dir/$id.$type";
    ok(-s $example_file, "example $type file exists: $example_file");
    is(File::Compare::compare($file, $example_file), 0, "$type file matches example file");
}

done_testing();
exit;

#$HeadURL$
#$Id$
