#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Data::Dumper;
use Test::More tests => 48;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

BEGIN {
    use_ok('Genome::ProcessingProfile::Command::Create');
}

my %pp_params = (
    'AmpliconAssembly' => {
        name => '16S AB 11F to 1391R (907R)',
        sequencing_platform => 'sanger',
        assembler => 'phredphrap',
        sequencing_center => 'gsc',
        assembly_size => 12345,
        region_of_interest => '16S',
        purpose => 'composition',
        primer_amp_forward => '11F:ATGC',
        primer_amp_reverse => '1391R:GCAT',
        #primer_seq_forward => '',
        primer_seq_reverse => '907R:AAGGTTCC',
    },
    'ReferenceAlignment' => {
        name => 'test_reference_alignment',
        sequencing_platform => 'solexa',
        read_aligner_name => 'maq0_6_8',
        reference_sequence_name => 'refseq-for-test',
        dna_type => 'genomic dna',
    },
    'Assembly' => {
        name => 'test_assembly',
        sequencing_platform => '454',
        assembler_name => 'newbler',
	assembler_params => 'test',
	assembler_version => '2.0.00.20',
    },
    'MicroArrayAffymetrix' => {
        name => 'test_micro_array_affymetrix',
    },
    'MicroArrayIllumina' => {
        name => 'test_micro_array_illumina',
    },
);

# create the processing profile
# 2 tests each
for my $subclass (keys %pp_params) {
    my $class = sprintf('Genome::ProcessingProfile::Command::Create::%s', $subclass);
    my $create_command = $class->create($pp_params{$subclass});
    isa_ok($create_command,$class);
    ok($create_command->execute,'execute '. $class->command_name);
}

# try to create an exact duplicate pp
# 4 tests each
for my $subclass (keys %pp_params) {
    my $class = sprintf('Genome::ProcessingProfile::Command::Create::%s', $subclass);
    my $create_command = $class->create($pp_params{$subclass});
    isa_ok($create_command,$class);
    $create_command->dump_error_messages(0);
    $create_command->queue_error_messages(1);

    ok(!$create_command->execute,'exact duplicate failed to execute '. $class->command_name);

    my @error_messages = $create_command->error_messages();
    ok(scalar(@error_messages), 'Failed execution did emit some error_messages');
    is($error_messages[0], 'Processing profile (above) with same name already exists', 'Error complains about duplicate name');
}

# try to create a pp with the same params, different name
# 4 tests each
for my $subclass (keys %pp_params) {
    my $class = sprintf('Genome::ProcessingProfile::Command::Create::%s', $subclass);
    # Skip classes that don't have params
    next unless $class->get_class_object->get_property_objects;

    # Create 'new' name
    my %params = %{$pp_params{$subclass}}; # Copy so we don't stomp on the name
    $params{name} .= '_duplicate';
    my $create_command = $class->create(%params);
    isa_ok($create_command,$class);

    $create_command->dump_error_messages(0);
    $create_command->queue_error_messages(1);
    ok(!$create_command->execute,'duplicate params failed to execute '. $class->command_name);

    my @error_messages = $create_command->error_messages();
    ok(scalar(@error_messages), 'Failed execution did emit some error_messages');
    is($error_messages[0], 'Existing processing profile(s) (above) with identical params, but different names already exist', 'Error messages complains about identical params');
}

# Get the PP via the name
# one test each
for my $subclass (keys %pp_params) {
    my $class = sprintf('Genome::ProcessingProfile::%s', $subclass);
    my @pp = $class->get(name => $pp_params{$subclass}->{name});
    is(scalar(@pp), 1, "Got one $subclass processing profile");
}

exit;

#$HeadURL$
#$Id$
