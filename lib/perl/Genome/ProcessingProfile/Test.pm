package Genome::ProcessingProfile::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
use Genome;
use Test::More;

#< Processing Profile and Commands for Testing >#
class Genome::ProcessingProfile::Tester {
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
    # Attrs
        sequencing_platform => { 
            is => 'Text',
            doc => 'The sequencing_platform of this profile',
        },
        dna_source => {
            is => 'Text',
            default_value => 'genomic',
            valid_values => [qw/ genomic metagenomic /],
            doc => 'The dna source of this profile',
        },
        roi => {
            is => 'Text',
            is_optional => 1,
            doc => 'This param may be undefined.',
        },
    ],
};
sub Genome::ProcessingProfile::Tester::stages {
     return (qw/ prepare assemble /);
}
sub Genome::ProcessingProfile::Tester::prepare_job_classes {
     return (qw/ 
         Genome::ProcessingProfile::Tester::Prepare 
         /);
}
sub Genome::ProcessingProfile::Tester::prepare_objects {
    return 1;
}
sub Genome::ProcessingProfile::Tester::assemble_job_classes {
     return (qw/ 
         Genome::ProcessingProfile::Tester::PreAssemble 
         Genome::ProcessingProfile::Tester::Assemble 
         Genome::ProcessingProfile::Tester::PostAssemble 
         /);
}
sub Genome::ProcessingProfile::Tester::assemble_objects {
    return 1;
}

# Prepare
class Genome::ProcessingProfile::Tester::Prepare {
    is => 'Genome::Model::Event',
};

# Assemble
class Genome::ProcessingProfile::Tester::PreAssemble {
    is => 'Genome::Model::Event',
};
class Genome::ProcessingProfile::Tester::Assemble {
    is => 'Genome::Model::Event',
};
class Genome::ProcessingProfile::Tester::PostAssemble {
    is => 'Genome::Model::Event',
};
#<>#
sub test_class {
    return 'Genome::ProcessingProfile';
}

sub params_for_test_class {
    my %params = Genome::ProcessingProfile::Test->valid_params_for_type_name('tester');
    delete $params{class};
    return %params;
}

sub required_params_for_class {
    return (qw/ name /);
}

sub test_startup : Test(startup => 2) {
    my $self = shift;

    $ENV{UR_DBI_NO_COMMIT} = 1;
    ok($ENV{UR_DBI_NO_COMMIT}, 'No commit') or die;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    ok($ENV{UR_USE_DUMMY_AUTOGENERATED_IDS}, 'Dummy ids') or die;

    return;
}
    
sub test01_creates : Tests(7) {
    my $self = shift;

    # Get params, put into separate varibales for clarity.
    my %params = $self->params_for_test_class;
    my ($name, $type_name, $sequencing_platform, $dna_source, $roi) = 
    @params{qw/
        name type_name sequencing_platform dna_source roi
        /}; 

    #< VALID CREATES >#
    do {
        # roi is undef
        my $created = $self->test_class->create(
            name => 'No Region of Interest (ROI)',
            type_name => $type_name,
            sequencing_platform => $sequencing_platform,
            dna_source => $dna_source,
            roi => undef,
        );
        ok($created, 'Create w/ roi undef'); # we now have 2 pp in memory, the one above and the original with all params defined 
        is(ref($created), $created->subclass_name, 'subclass_name is correctly filled in');
    };

    #< INVALID CREATES >#
    eval {
        $self->test_class->create(
            name => 'Invalid Type Name', # name must be different cuz it is checked first
            type_name => 'not tester',
            dna_source => $dna_source,
            roi => $roi,
        )
    };
    ok(
        $@,
        "Failed as expected - create w/ invalid type name => 'not tester'"
    );
    ok( # w/o sequencing platform (required)
        !$self->test_class->create(
            name => 'Dna Source is undef', # name must be different cuz it is checked first
            type_name => $type_name,
            dna_source => $dna_source,
            roi => $roi,
        ),
        'Failed as expected - tried to create w/o dna_source',
    );
    ok( # w/ invalid dna source (valid values)
        !$self->test_class->create(
            name => 'Dna Source is invalid', # name must be different cuz it is checked first
            type_name => $type_name,
            sequencing_platform => $sequencing_platform,
            dna_source => 'invalid dna source',
            roi => $roi,
        ),
        'Failed as expected - tried to create w/ invalid dna_source',
    );
    ok( # duplicate name and params (name is checked first)
        !$self->test_class->create(
            name => $name, 
            type_name => $type_name,
            sequencing_platform => $sequencing_platform,
            dna_source => $dna_source,
            roi => $roi,
        ),
        'Create failed as expected - pp with same name'
    );
    ok( # duplicate params w/ different name (name is checked first)
        !$self->test_class->create(
            name => 'Diff Name',
            type_name => $type_name,
            sequencing_platform => $sequencing_platform,
            dna_source => $dna_source,
            roi => $roi,
        ),
        'Create failed as expected - pp with different name, but same params',
    );
    ok( # check that default values are set by creating w/ duplicate params w/o dna_source
        !$self->test_class->create(
            name => 'Diff Name',
            type_name => $type_name,
            sequencing_platform => $sequencing_platform,
            roi => $roi,
        ),
        'Create failed as expected - pp with same params, setting the default value for dna_source',
    );
    ok( # duplicate params w/ roi undef - checks undef params
        !$self->test_class->create(
            name => 'Yet Another No Region of Interest (ROI)',
            type_name => $type_name,
            sequencing_platform => $sequencing_platform,
            dna_source => $dna_source,
            roi => undef,
        ),
        'Failed as expected - create w/ identical params (roi undef)',
    );

    
    # TYPE NAME UNRESOLVABLE
    eval { # this should die
        $self->test_class->create(
            name => 'Diff Name',
            sequencing_platform => $sequencing_platform,
            dna_source => $dna_source,
            roi => $roi,
        );
    };
    ok($@, 'Create failed - can\'t resolve type_name');

    return 1;
}

sub test02_type_name_resolvers : Tests(3) {
    my $self = shift;

    is(
        Genome::ProcessingProfile::Tester->_resolve_type_name_for_class,
        'tester',
        '_resolve_type_for_subclass_name Genome::ProcessingProfile::Tester => tester',
    );
    is(
        Genome::ProcessingProfile->_resolve_type_name_for_class,
        undef, 
        '_resolve_type_for_subclass_name Genome::ProcessingProfile => undef ',
    );
    is(
        Genome::ProcessingProfile->_resolve_subclass_name_for_type_name('tester'),
        'Genome::ProcessingProfile::Tester',
        '_resolve_subclass_name_for_type_name tester => Genome::ProcessingProfile::Tester'
    );

    return 1;
}

sub test03_methods : Tests(4) {
    my $self = shift;

    my $pp = $self->{_object};
    is($pp->type_name, 'tester', 'Checking type_name (tester)');
    is_deeply([ $pp->params_for_class ], [qw/ sequencing_platform dna_source roi /], 'params_for_class');
    is($pp->sequencing_platform, 'solexa', 'sequencing_platform (solexa)');
    is($pp->dna_source, 'genomic', 'dna_source (genomic)');

    return 1;
}

#< MOCK ># 
sub create_mock_processing_profile {
    my ($self, $type_name) = @_; # seq plat for ref align

    # Create
    my %params = $self->valid_params_for_type_name($type_name);
    unless ( %params ) {
        confess "No params for type name ($type_name).";
    }
    my %create_params = map { $_ => delete $params{$_} } (qw/ class name type_name /);
    my $pp = $self->create_mock_object(%create_params)
        or confess "Can't create mock processing profile for '$type_name'";
    $DB::single = 1; 
    # Methods 
    $self->mock_methods(
        $pp,
        (qw/
            _initialize_model
            _initialize_build 
            _generate_events_for_build
            _generate_events_for_build_stage
            _generate_events_for_object
            _resolve_workflow_for_build
            _workflow_for_stage
            _merge_stage_workflows
            _resolve_log_resource
            _resolve_disk_group_name_for_build
            _build_success_callback
            params_for_class
            stages objects_for_stage classes_for_stage
            delete
            /),
    );

    # PP Params
    for my $param ( $pp->params_for_class ) {
        $self->mock_accessors($pp, $param);
        $pp->$param( delete $params{$param} );
    }

    # Stages
    for my $stage ( $pp->stages ) {
        $self->mock_methods(
            $pp,
            $stage.'_objects', $stage.'_job_classes',
        );
    }

    #< Specific Mocking >#
    my $additional_methods_method = '_add_mock_methods_to_'.join(
        '_', split(/\s/, $pp->type_name)
    );
    if ( $self->can($additional_methods_method) ) {
        $self->$additional_methods_method($pp)
            or confess "Can't add additional methods for $type_name";
    }

    return $pp;
}

#< Valid Params >#
my %TYPE_NAME_PARAMS = (
    tester => {
        class => 'Genome::ProcessingProfile::Tester',
        type_name => 'tester',
        name => 'Tester for Testing',
        sequencing_platform => 'solexa',
        dna_source => 'genomic',
        roi => 'mouse',
    }, 
    'amplicon assembly' => {
        class => 'Genome::ProcessingProfile::AmpliconAssembly',
        type_name => 'amplicon assembly',
        name => '16S Test 27F to 1492R (907R)',
        assembler => 'phredphrap',
        assembly_size => 1465,
        primer_amp_forward => '18SEUKF:ACCTGGTTGATCCTGCCAG',
        primer_amp_reverse => '18SEUKR:TGATCCTTCYGCAGGTTCAC',
        primer_seq_forward => '502F:GGAGGGCAAGTCTGGT',
        primer_seq_reverse => '1174R:CCCGTGTTGAGTCAAA',
        purpose => 'composition',
        region_of_interest => '16S',
        sequencing_center => 'gsc',
        sequencing_platform => 'sanger',
    }, 
    'metagenomic composition 16s sanger' => {
        class => 'Genome::ProcessingProfile::MetagenomicComposition16s',
        type_name => 'metagenomic composition 16s',
        name => '16S Test Sanger',
        amplicon_size => 1150,
        sequencing_center => 'gsc',
        sequencing_platform => 'sanger',
        assembler => 'phred_phrap',
        assembler_params => '-vector_bound 0 -trim_qual 0',
        trimmer => 'finishing',
        classifier => 'rdp2-1',
        classifier_params => '-training_set broad',
    }, 
    'metagenomic composition 16s 454' => {
        class => 'Genome::ProcessingProfile::MetagenomicComposition16s',
        type_name => 'metagenomic composition 16s',
        name => '16S Test 454',
        amplicon_size => 200,
        sequencing_center => 'gsc',
        sequencing_platform => '454',
        classifier => 'rdp2-1',
        classifier_params => '-training_set broad',
    }, 
    'reference alignment solexa' => {
        class => 'Genome::ProcessingProfile::ReferenceAlignment::Solexa',
        type_name => 'reference alignment',
        name => 'Ref Align Solexa Test',
        sequencing_platform => 'solexa',
        dna_type => 'genomic dna',
        snv_detector_name => 'samtools',
        genotyper_params => undef,
        indel_finder_name => undef,
        indel_finder_params => undef,
        multi_read_fragment_strategy => undef,
        read_aligner_name => 'bwa',
        read_aligner_version => undef,
        read_aligner_params => undef,
        read_calibrator_name => undef,
        read_calibrator_params => undef,
        prior_ref_seq => undef,
        reference_sequence_name => undef,
        align_dist_threshold => undef,
    },
    'reference alignment 454' => {
        class => 'Genome::ProcessingProfile::ReferenceAlignment::454',
        type_name => 'reference alignment',
        name => 'Ref Align 454 Test',
        sequencing_platform => '454',
        dna_type => 'genomic dna',
        snv_detector_name => 'samtools',
        genotyper_params => undef,
        indel_finder_name => undef,
        indel_finder_params => undef,
        multi_read_fragment_strategy => undef,
        read_aligner_name => 'maq',
        read_aligner_version => undef,
        read_aligner_params => undef,
        read_calibrator_name => undef,
        read_calibrator_params => undef,
        prior_ref_seq => undef,
        reference_sequence_name => undef,
        align_dist_threshold => undef,
    },
    'de novo assembly' => {
        class => 'Genome::ProcessingProfile::DeNovoAssembly',
        name => 'Duh Novo Test',
        type_name => 'de novo assembly',
        sequencing_platform => 'solexa',
        assembler_name => 'velvet',
        assembler_version => '0.7.30',
        assembler_params => '-hash_length 27 ',
        prepare_instrument_data_params => '-reads_cutoff 10000',
    },
    'virome screen' => {
	class => 'Genome::ProcessingProfile::ViromeScreen',
	name => 'Virome Screen Test',
	type_name => 'virome screen',
	sequencing_platform => '454',
    },
);
sub valid_params_for_type_name {
    my ($self, $type_name) = @_;

    confess "No type name given" unless $type_name;

    my ($match) = grep { m#$type_name# } sort { $b cmp $a } keys %TYPE_NAME_PARAMS;
    
    return unless exists $TYPE_NAME_PARAMS{$match};

    return %{$TYPE_NAME_PARAMS{$match}};
}

#< Additional Methods for Mock PP Type Names >#
# TODO
#sub _add_mock_methods_to_amplicon_assembly { }
sub _add_mock_methods_to_metagenomic_composition_16s {
    my ($self, $pp) = @_;

    $self->mock_methods(
        $pp, 
        (qw/ 
            _operation_params_as_hash
            assembler_params_as_hash classifier_params_as_hash trimmer_params_as_hash
            /),
    );

    return 1;
}

sub _add_mock_methods_to_de_novo_assembly { 
    my ($self, $pp) = @_;

    $self->mock_methods(
        $pp, 
        (qw/ 
            get_param_string_as_hash _validate_params_for_step 
            get_prepare_instrument_data_params get_assemble_params get_preprocess_params 
            /),
    );

    return 1;
}

#sub _add_mock_methods_to_tester { }
#sub _add_mock_methods_to_reference_alignement { }

# NO ADDITIONAL METHODS TO MOCK FOR VIROME SCREEN
#sub _add_mock_methods_to_virome_screen { }

#######################
# Type Name Test Base #
#######################

package Genome::ProcessingProfile::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
require Scalar::Util;
use Test::More;

sub pp { # the valid processing profile
    return $_[0]->{_object};
}

sub class_name {
    return ( Scalar::Util::blessed($_[0]) || $_[0] );
}

sub test_class {
    my $class = $_[0]->class_name;
    $class =~ s#::Test$##;
    return $class
}

sub type_name {
    my ($subclass) = $_[0]->test_class =~ m#Genome::ProcessingProfile::(\w+)#;
    return Genome::Utility::Text::camel_case_to_string($subclass);
}

sub full_type_name {
    my ($subclass) = $_[0]->test_class =~ m#Genome::ProcessingProfile::(.+)#;
    return join(
        ' ',
        map { Genome::Utility::Text::camel_case_to_string($_) }
        split('::', $subclass)
    );
}

sub params_for_test_class {
    my $self = shift;

    unless ( $self->{_params_for_class} ){
        my %params = Genome::ProcessingProfile::Test->valid_params_for_type_name( $self->full_type_name );
        delete $params{class};
        for my $key ( keys %params ) {
            delete $params{$key} unless defined $params{$key};
        }
        $self->{_params_for_class} = \%params;
    }

    return %{$self->{_params_for_class}};
}

# TODO test params?

#####################
# Amplicon Assembly #
#####################

package Genome::ProcessingProfile::AmpliconAssembly::Test;

use strict;
use warnings;

use base 'Genome::ProcessingProfile::TestBase';

sub invalid_params_for_test_class {
    return (
        primer_amp_forward => 'AAGGTGAGCCCGCGATGCGAGCTTAT',
        primer_amp_reverse => '55:55',
        sequencing_platform => 'super-seq',
        sequencing_center => 'monsanto',
        purpose => 'because',
    );
}

###############################
# Metagenomic Composition 16s #
###############################

package Genome::ProcessingProfile::MetagenomicComposition16s::Test;

use strict;
use warnings;

use base 'Genome::ProcessingProfile::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub params_for_test_class {
    my $self = shift;
    my %params = $self->SUPER::params_for_test_class;
    $params{classifier} = 'kroyer';
    return %params;
}

sub test01_param_hashes : Tests() {
    my $self = shift;
    
    my %assembler_params = $self->pp->assembler_params_as_hash;
    is_deeply(
        \%assembler_params,
        { vector_bound => 0, trim_qual => 0 },
        'assembler params as hash'
    );

    my %trimmer_params = $self->pp->trimmer_params_as_hash;
    is_deeply(
        \%trimmer_params,
        {},
        'trimmer params as hash'
    );

    my %classifier_params = $self->pp->classifier_params_as_hash;
    is_deeply(
        \%classifier_params,
        { training_set => 'broad' },
        'classifier params as hash'
    );

    return 1;
}

sub test02_stages : Tests() {
    my $self = shift;
    
    my @stages = $self->pp->stages;
    is_deeply(\@stages, [qw/ one /], 'Stages');
    my @stage_one_classes = $self->pp->classes_for_stage($stages[0]);
    #print Dumper(\@stage_one_classes);
    is_deeply(
        \@stage_one_classes, 
        [qw/
        Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Sanger
        Genome::Model::Event::Build::MetagenomicComposition16s::Trim::Finishing
        Genome::Model::Event::Build::MetagenomicComposition16s::Assemble::PhredPhrap
        Genome::Model::Event::Build::MetagenomicComposition16s::Classify
        Genome::Model::Event::Build::MetagenomicComposition16s::Orient
        Genome::Model::Event::Build::MetagenomicComposition16s::Reports
        Genome::Model::Event::Build::MetagenomicComposition16s::CleanUp
        /], 
        'Stage one classes'
    );
    return 1;
}

############
# Commands #
############

package Genome::ProcessingProfile::Command::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

sub test_class {
    return 'Genome::ProcessingProfile::Command::'.$$_[0]->subclass;
}

sub command_name {
    return Genome::Utility::Text::camel_case_to_string($_[0]->subclass);
}

sub params_for_test_class {
    return (
        $_[0]->_params_for_test_class,
    );
}

sub _params_for_test_class { 
    return;
}

sub test01_execute : Tests() {
    my $self = shift;

    ok($self->{_object}->execute, 'Executed '.$self->command_name);

    return 1;
}

sub test01_invalid : Tests() {
    my $self = shift;

    #ok($self->{_object}->execute, 'Executed '.$self->command_name);

    return 1;
}

1;

#$HeadURL$
#$Id$
