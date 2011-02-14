#!/gsc/bin/perl
#
# FIXME  test existed. Write some, please.
#
# 2010jul30 ebelter 
#  added tests for dumping fasta, qual and fastq
# 2010aug4 ebelter 
#  added tests for the 4 ways you can get an sff file

use strict;
use warnings;

use above 'Genome';

require File::Compare;
require File::Temp;
use Genome::Config;
use Genome::Utility::TestBase;
require IO::File;
require Test::MockObject;
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
) or die "Unable to create mock 454 inst data";
$id454->set_always('sff_file', "$dir/$id.sff");
Genome::Utility::TestBase->mock_methods(
    $id454,
    (qw/
        sff_file
        dump_sanger_fastq_files 
        dump_fasta_file dump_qual_file _run_sffinfo
        /)
) or die "Can't mock 454 methods";
# run region
my $rr454 = Test::MockObject->new();
my $rr454_sff_filesystem_location_string;
$rr454->mock('sff_filesystem_location_string', sub{ return $rr454_sff_filesystem_location_string; });
$rr454->mock('dump_sff', sub{ 
        my ($self, %params) = @_;
        my $sff_file = $params{filename};
        die "No sff filename" unless $sff_file;
        die "Bad sff filename, starts w/ gsc in it!" if $sff_file =~ m#/gsc#;
        my $fh = IO::File->new('>'.$sff_file) or die $!;
        $fh->print("SFF!\n");
        $fh->close;
        return 1; 
    });
$id454->set_always('run_region_454', $rr454);
# region index
my $ri454 = Test::MockObject->new();
$ri454->mock('index_sequence', sub{ return; });
$id454->set_always('region_index_454', $ri454);

# disk allocation
my $disk_allocation = Genome::Utility::TestBase->create_mock_object(
    class => 'Genome::Disk::Allocation',
    absolute_path => $dir,
);
$disk_allocation = Test::MockObject->new();
$disk_allocation->set_always('absolute_path', $dir);
ok($disk_allocation, 'created mock disk allocation') or die;
is($disk_allocation->absolute_path, $dir, 'disk allocation absolute path points to test dir') or die;
no warnings;
*Genome::Disk::Allocation::get = sub{ return $disk_allocation; };
*Genome::Disk::Allocation::allocate = sub{ return $disk_allocation; };
*Genome::Sys::lock_resource = sub{ ok(1, 'lock'); return 1; };
*Genome::Sys::unlock_resource = sub{ ok(1, 'unlock'); return 1; };
use warnings;

# sff already dumped to disk allocation
my $sff_file = $id454->sff_file;
is($sff_file, $dir."/$id.sff", 'sff file from allocation already dumped');
# test fasta, qual, fastq files and names w/ this real sff
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

# AFTER THIS POINT THE SFF IS INVALID!!
# sff dump to new disk allocation
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
$disk_allocation = Test::MockObject->new();
$disk_allocation->set_always('absolute_path', $tmpdir);
is($disk_allocation->absolute_path, $tmpdir, 'disk allocation absolute path points to tmp dir') or die;
$sff_file = $id454->sff_file;
is($sff_file, $tmpdir."/$id.sff", 'sff file from dumped to allocation');
# sff from run region 454
$rr454_sff_filesystem_location_string = 'SFF from RR454';
$sff_file = $id454->sff_file;
is($sff_file, $rr454_sff_filesystem_location_string, 'sff file from run region 454');
# sff from region index 454
$ri454->mock('index_sequence', sub{ return 1; });
my $index_sff = Test::MockObject->new();
$index_sff->set_always('stringify', 'SFF from RI454');
$ri454->mock('get_index_sff', sub{ return $index_sff; });
$sff_file = $id454->sff_file;
is($sff_file, 'SFF from RI454', 'sff file from region index 454');

done_testing();
exit;

