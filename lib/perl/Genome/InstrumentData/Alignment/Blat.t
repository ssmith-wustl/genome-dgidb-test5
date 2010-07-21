#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

BEGIN {
    plan skip_all => 'THIS IS OBSOLETE, USE ALIGNMENT RESULT INSTEAD!';
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    }
    plan tests => 4;
    use_ok('Genome::InstrumentData::Alignment::Blat');
}

my $fasta_file = '/gsc/var/cache/testsuite/data/Genome-Model-Command-Build-ReferenceAlignment-AlignReads-Blat/test_a.fa';
# TODO: Add an sff_file to the read_set
my $bogus_id = 0;
my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);

my $instrument_data = Genome::InstrumentData::454->create_mock(
                                                               id => --$bogus_id,
                                                               genome_model_run_id => $bogus_id,
                                                               sample_name => 'test_sample_name',
                                                               sequencing_platform => '454',
                                                               run_name => 'test_run',
                                                               subset_name => 'test_subset',
                                                    );
isa_ok($instrument_data,'Genome::InstrumentData::454');
$instrument_data->set_always('full_path',$tmp_dir);
$instrument_data->set_always('fasta_file', $fasta_file);
$instrument_data->set_always('dump_to_file_system', 1);
$instrument_data->set_always('sample_type','dna');
$instrument_data->set_always('is_external',0);

my $allocation = Genome::Disk::Allocation->create_mock(
                                                       id => --$bogus_id,
                                                       allocation_path => 'alignment_data/blat/refseq-for-test/test_run/test_subset_'.$instrument_data->id,
                                                       allocator_id => $bogus_id,
                                                       disk_group_name => 'bogus_disk_group',
                                                       group_subdirectory => '',
                                                       kilobytes_requested => 1,
                                                       kilobytes_used => 1,
                                                       mount_path => '/gscmnt/nowhere',
                                                       owner_class_name => ref($instrument_data),
                                                       owner_id => $instrument_data->id,
                                                   );
my $alignment_dir = $tmp_dir.'/alignments';
Genome::Utility::FileSystem->create_directory($alignment_dir);
$allocation->set_always('absolute_path',$alignment_dir);
$instrument_data->set_list('allocations',$allocation);


my $alignment = Genome::InstrumentData::Alignment::Blat->create(
                                                                reference_name => 'refseq-for-test',
                                                                instrument_data_id => $instrument_data->id,
                                                            );
isa_ok($alignment,'Genome::InstrumentData::Alignment::Blat');
ok($alignment->find_or_generate_alignment_data,'generate alignment data');
exit;
