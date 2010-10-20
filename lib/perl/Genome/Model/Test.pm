package Genome::Model::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
require File::Temp;
require Genome;
require Genome::ProcessingProfile::Test;
require Genome::Utility::Text;
use Test::More;

#< Tester Type Name >#
class Genome::Model::Tester { # 'real' model for testing
    is => 'Genome::Model',
    has => [
        ( map { $_ => { via => 'processing_profile' } } Genome::ProcessingProfile::Tester->params_for_class ),
        coolness => {
            via => 'inputs',
            is_mutable => 1,
            where => [ name => 'coolness', value_class_name => 'UR::Value' ],
            to => 'value_id',
            doc => 'The level of coolness of this model.',
        },
        inst_data => {
            is => 'Genome::InstrumentData',
            via => 'inputs',
            is_mutable => 1,
            is_many => 1,
            where => [ name => 'instrument_data' ],
            to => 'value',
            doc => 'Instrument data',
        },
        friends => {
            is => 'Text',
            via => 'inputs',
            is_mutable => 1,
            is_many => 1,
            where => [ name => 'friends', value_class_name => 'UR::Value', ],
            to => 'value_id',
            doc => 'Friends of the model.',
        },
    ],
};

class Genome::Model::Build::Tester { # 'real' model for testing
    is => 'Genome::Model::Build',
    has => [
        coolness => {
            via => 'inputs',
            where => [ name => 'coolness', value_class_name => 'UR::Value' ],
            to => 'value_id',
            doc => 'The level of coolness of the model when built.',
        },
    ],
};

sub test_class {
    return 'Genome::Model';
}

sub params_for_test_class {
    return (
        name => 'Test Sweetness',
        subject_name => $_[0]->mock_sample_name,
        subject_type => 'sample_name',
        data_directory => $_[0]->tmp_dir,
        processing_profile_id => $_[0]->_tester_processing_profile->id,
    );
}

sub required_params_for_class {
    return (qw/ subject_name processing_profile_id /);
}

sub invalid_params_for_test_class {
    return (
        subject_name => 'invalid_subject_name',
        subject_type => 'invalid_subject_type',
        processing_profile_id => '-999999',#'duidudrted',
    );
}

sub _model { # real model we are creating
    return $_[0]->{_object};
}

sub mock_sample_name {
    return 'H_GV-933124G-S.MOCK',
}

sub _instrument_data {
    return $_[0]->{_instrument_data}
}

sub _tester_processing_profile {
    my $self = shift;

    unless ( $self->{_processing_profile} ) {
    $self->{_processing_profile} = Genome::ProcessingProfile::Test->create_mock_processing_profile('tester')
        or confess;
    }
    return $self->{_processing_profile};
}

sub test_startup : Test(startup => 3) {
    my $self = shift;

    # UR
    $ENV{UR_DBI_NO_COMMIT} = 1;
    ok($ENV{UR_DBI_NO_COMMIT}, 'No commit') or confess;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    ok($ENV{UR_USE_DUMMY_AUTOGENERATED_IDS}, 'Dummy ids') or confess;
    ok($self->create_mock_sample, 'Create mock sample');

    return 1;
}

sub test_shutdown : Test(shutdown => 1) {
    my $self = shift;

    ok($self->_model->delete, 'Delete model');

    return 1;
}

sub test00_invalid_creates : Tests(4) {
    my $self = shift;

    my %params = $self->params_for_test_class;

    # try to recreate
    ok(!$self->test_class->create(%params), 'Recreate fails');

    return 1;
}

sub test01_directories_and_links : Tests(4) {
    my $self = shift;

    my $model = $self->_model;
    is($model->data_directory, $self->tmp_dir, "Model data directory");
    ok($model->resolve_data_directory, "Resolve data directory");
    ok(-d $model->alignment_links_directory, "Alignment links directory");
    ok(-d $model->base_model_comparison_directory, "Model comparison directory");

    return 1;
}

sub test02_instrument_data : Tests() { 
    my $self = shift;

    my $model = $self->_model;
    my @instrument_data = $self->create_mock_solexa_instrument_data(2); # dies if no workee

    # overwrite G:ID get to not do a full lookup and save time (~ 10 sec)
    no warnings qw/ once redefine /;
    local *Genome::InstrumentData::get = sub{ return @instrument_data; };
    
    # compatible
    my @compatible_id = $model->compatible_instrument_data;
    is_deeply(
        \@compatible_id,
        \@instrument_data,
        "compatible_instrument_data"
    );

    # available/unassigned
    can_ok($model, 'unassigned_instrument_data'); # same as available
    my @available_id = $model->available_instrument_data;
    is_deeply(
        \@available_id,
        \@compatible_id,
        "available_instrument_data"
    );

    ## Can't get instrument_data_assignments to work...so overwrite 
    my @idas = $self->create_mock_instrument_data_assignments($model, @instrument_data);
    local *Genome::Model::instrument_data_assignments = sub{ return @idas; };
    $idas[0]->first_build_id(1);
    my @model_id = $model->instrument_data;
    is_deeply(\@model_id, \@instrument_data, 'instrument_data');
    my @built_id = $model->built_instrument_data; # should by id[0]
    is_deeply(\@built_id, [ $instrument_data[0] ], 'built_instrument_data');
    my @unbuilt_id = $model->unbuilt_instrument_data; # should by id[1]
    is_deeply(\@unbuilt_id, [ $instrument_data[1] ], "unbuilt_instrument_data");

    return 1;
}

sub test03_inputs : Tests() {
    my $self = shift;

    my $model = $self->_model;
    # Coolness tests setting a primitive.  Could not get this to work thru UR
    my $coolness = 'high';
    ok($model->coolness($coolness), 'set input coolness'); 
    is($model->coolness($coolness), $coolness, 'got input coolness'); 
    
    # Intr data - this will be how instr data will be defined in the future
    my $inst_data = Genome::InstrumentData::Sanger->get('2sep09.934pmaa1');
    ok($inst_data, 'Got sanger instrument data');
    ok($model->add_inst_data($inst_data), 'add_inst_data');
    is_deeply([$model->inst_data], [$inst_data], 'inst_data');
    ok($model->remove_inst_data($inst_data), 'remove_inst_data');
    ok(!$model->inst_data, 'removed instrument data');
    
    return 1;
}

sub test04_subjects : Tests() {
    my $self = shift;
    
    my $mock_sample = Genome::Sample->get(name => $self->mock_sample_name);
    
    my %params = $self->params_for_test_class;
    
    delete $params{subject_name};
    delete $params{subject_type};
    $params{name} .= ' 2 - Now with improved Subject tracking!'; #avoid same model name
    
    $params{subject_id} = $self->_model->id;
    $params{subject_class_name} = 'Genome::Sample';
    
    ok(!$self->test_class->create(%params), 'Failed to create model with nonexistent sample');
    
    delete $params{subject_id}; 
    ok(!$self->test_class->create(%params), 'Failed to create model without subject_id');
    
    $params{subject_id} = $mock_sample->id;
    my $created = $self->test_class->create(%params);
    ok($created, 'Created model based on subject_id and subject_class_name');

    is(ref($created), $created->subclass_name, 'subclass_name property is correctly filled in');
}

sub test05_builds : Tests() {
    my $self = shift;

    my $model = $self->_model;
    # create these in reverse order because of negative ids
    my $build2 = $self->add_mock_build_to_model($model);
    my $build1 = $self->add_mock_build_to_model($model);
    $build1->build_event->date_completed(undef);
    $build1->build_event->event_status('Running');

    local *Genome::Model::builds = sub{ return ($build1, $build2); };
    my @builds = $model->builds;

    my @completed_builds = $model->completed_builds;
    is($completed_builds[0]->id, $build2->id, 'Got completed builds');
    is($model->last_complete_build->id, $build2->id, 'Got last completed build');
    is($model->last_complete_build_id, $build2->id, 'Got last completed build id');
    is($model->_last_complete_build_id, $build2->id, 'Got _last completed build id');
    my @succeed_builds = $model->succeeded_builds;
    is($succeed_builds[0]->id, $build2->id, 'Got succeeded builds');
    is($model->last_succeeded_build->id, $build2->id, 'Got last succeeded build');
    is($model->last_succeeded_build_id, $build2->id, 'Got last succeeded build id');

    my @running_builds = $model->running_builds;
    is($running_builds[0]->id, $build1->id, 'Got running builds');

    $build1->build_event->date_completed(UR::Time->now);
    $build1->build_event->event_status('Succeeded');

    @completed_builds = $model->completed_builds;
    is_deeply([ map { $_->id } @completed_builds], [$build1->id, $build2->id], 'Got completed builds after build 1 is succeeded');
    is($model->last_complete_build->id, $build2->id, 'Got last completed build after build 1 is succeeded');
    is($model->last_complete_build_id, $build2->id, 'Got last completed build id after build 1 is succeeded');
    is($model->_last_complete_build_id, $build2->id, 'Got _last completed build id after build 1 is succeeded');
    @succeed_builds = $model->succeeded_builds;
    is_deeply([map { $_->id } @succeed_builds], [$build1->id, $build2->id], 'Got succeeded builds after build 1 is succeeded');
    is($model->last_succeeded_build->id, $build2->id, 'Got last succeeded build after build 1 is succeeded');
    is($model->last_succeeded_build_id, $build2->id, 'Got last succeeded build id after build 1 is succeeded');

    return 1;
}

#< MOCK ># 
sub mock_model_dir_for_type_name {
    confess "No type name given" unless $_[1];
    return $_[0]->dir.'/'.Genome::Utility::Text::string_to_camel_case($_[1]);
}

sub create_basic_mock_model {
    my ($self, %params) = @_;

    # Processing profile
    my ($pp, $type_name);
    if ( exists $params{type_name} ) {
        $type_name = $params{type_name};
        $pp = Genome::ProcessingProfile::Test->create_mock_processing_profile($type_name)
            or confess "Can't create mock $type_name processing profile";    
    }
    elsif ( exists $params{processing_profile} ) {
        $pp = $params{processing_profile};
        $type_name = $pp->type_name;
    }
    else {
        confess "No processing profile or type name given to create mock model";
    }

    # Dir
    my $model_data_dir = ( delete $params{use_mock_dir} ) 
    ? $self->mock_model_dir_for_type_name($type_name)
    : File::Temp::tempdir(CLEANUP => 1);

    confess "Can't find mock model data directory: $model_data_dir" unless -d $model_data_dir;
    
    # Model
    my $sample = $self->create_mock_sample;
    my $model = $self->create_mock_object(
        class => 'Genome::Model::'.Genome::Utility::Text::string_to_camel_case($pp->type_name),
        name => 'mr. mock '.$type_name,
        subject_class_name => 'Genome::Sample',
        subject_id => $sample->id,
        subject_name => $sample->name,
        subject_type => 'sample_name',
        processing_profile_id => $pp->id,
        data_directory => $model_data_dir,
    )
        or confess "Can't create mock $type_name model";

    # Methods in base Genome::Model
    $self->mock_methods(
        $model, # added inst data until it gets back into the class def
        (qw/
            instrument_data
            builds_with_status abandoned_builds failed_builds running_builds scheduled_builds
            current_running_build current_running_build_id
            completed_builds last_complete_build last_complete_build_id 
            resolve_last_complete_build _last_complete_build_id 
            succeeded_builds last_succeeded_build last_succeeded_build_id
            compatible_instrument_data assigned_instrument_data unassigned_instrument_data
            /),
    ) or confess "Can't add mock methods to $type_name model";

    # Methods in subclass
    my $add_mock_methods_to_model = '_add_mock_methods_to_'.join('_', split(' ',$model->type_name)).'_model';
    if ( $self->can($add_mock_methods_to_model) ) {
        $self->$add_mock_methods_to_model($model)
            or confess;
    }

    return $model;
}

sub create_mock_model {
    my ($self, %params) = @_;

    my $model = $self->create_basic_mock_model(%params);
    confess "Can't create mock ".$model->type_name." model" unless $model;

    my $build = $self->add_mock_build_to_model($model)
        or confess "Can't add mock build to mock ".$model->type_name." model";

    if ( $model->sequencing_platform ) {
        my @idas = $self->create_and_assign_mock_instrument_data_to_model($model, $params{instrument_data_count})
            or confess "Can't add mock instrument data to mock ".$model->type_name." model";
    }
    
    return $model;
}
 
sub create_mock_sample {
    my $self = shift;

    my $taxon = $self->create_mock_object(
        class => 'Genome::Taxon',
        domain => 'Eukaryota',
        species_name => 'human',
        species_name => 'Homo sapiens',
        current_default_prefix => 'H_',
        legacy_org_id => 17,
        estimated_genome_size => 4500000,#3200000000,
        current_genome_refseq_id => 2817463805,
        ncbi_taxon_id => 9606,
    ) or confess "Can't create mock taxon";

    my $source = $self->create_mock_object(
        class => 'Genome::Individual',
        taxon_id => $taxon->id,
        name => $self->mock_sample_name,
    ) or confess "Can't create individual";

    my $sample = $self->create_mock_object(
        class => 'Genome::Sample',
        source_id => $source->id,
        source_type => 'organism_individual',
        taxon_id => $taxon->id,
        name => $self->mock_sample_name,
        common_name => 'normal',
        extraction_label => 'S.MOCK',
        extraction_type => 'genomic dna',
        extraction_desc => undef,
        cell_type => 'primary',
        gender => 'female',
        tissue_desc => 'skin, nos',
        tissue_label => '31412',
        organ_name => undef,
    ) or confess "Can't create mock sample";

    return $sample;
}

sub add_mock_build_to_model {
    my ($self, $model) = @_;

    confess "No model given to add mock build" unless $model;

    my $data_directory = $model->data_directory.'/build';
    my $build_class = 'Genome::Model::Build::'.Genome::Utility::Text::string_to_camel_case($model->type_name);
    if ( grep { $model->type_name eq $_ } ('metagenomic composition 16s', 'reference alignment') ) { # TODO add ref align too?
        print Dumper([$model, $model->processing_profile]);
        $build_class .= '::'.Genome::Utility::Text::string_to_camel_case($model->processing_profile->sequencing_platform);
    }
    
    # Build
    my $build = $self->create_mock_object(
        class => $build_class,
        model => $model,
        model_id => $model->id,
        data_directory => $data_directory,
        type_name => $model->type_name,
    ) or confess "Can't create mock ".$model->type_name." build";
    mkdir $data_directory unless -d $data_directory;

    $self->mock_methods(
        $build,
        (qw/
            reports_directory resolve_reports_directory
            build_event build_events status
            date_completed date_scheduled
            add_report get_report reports 
            start initialize success fail abandon delete
            metrics
            /),
    ) or confess "Can't add methods to mock build";

    # Inst Data
    $build->mock('instrument_data', sub{ return $_[0]->model->instrument_data; });
    
    # Event
    $self->add_mock_event_to_build($build)
        or confess "Can't add mock event to mock build";

    # Subclass specifics
    my $build_subclass_specifics_method = '_build_subclass_specifics_for_'.join('_', split(' ',$model->type_name));
    if ( $self->can($build_subclass_specifics_method) ) {
        $self->$build_subclass_specifics_method($build)
            or confess;
    }

    return $build;
}

sub add_mock_event_to_build {
    my ($self, $build) = @_;

    confess "No build given to add mock event" unless $build;

    my $event = $self->create_mock_object(
        class => 'Genome::Model::Event::Build',
        model_id => $build->model_id,
        build_id => $build->id,
        event_type => 'genome model build',
        event_status => 'Succeeded',
        user_name => $ENV{USER},
        date_scheduled => UR::Time->now,
        date_completed => UR::Time->now,
    ) or confess "Can't create mock build event for ".$build->type_name." build";

    $self->mock_methods(
        $event,
        (qw/ desc /),
    ) or confess "Can't add methods to mock build";

    return $event;
}

sub create_and_assign_mock_instrument_data_to_model {
    my ($self, $model, $cnt) = @_;

    confess "No model to create and assign instrument data" unless $model and $model->isa('Genome::Model');

    unless ( $model->sequencing_platform ) {
        confess "No sequencing platform to add mock instrument data to model";
    }

    # Instrument Data
    my $create_mock_instrument_data_method = sprintf(
        'create_mock_%s_instrument_data',
        $model->sequencing_platform,
    );
    unless ( $self->can($create_mock_instrument_data_method) ) {
        confess "No method to create ".$model->sequencing_platform." instrument data";
    }
    my @instrument_data = $self->$create_mock_instrument_data_method($cnt)
        or confess "Can't create mock ".$model->sequencing_platform." instrument data";

    # Instrument Data Assignments
    my @instrument_data_assignments = $self->create_mock_instrument_data_assignments($model, @instrument_data)
        or confess "Can't create mock instrument data assignments";

    return @instrument_data_assignments;
}

sub create_mock_instrument_data_assignments {
    my ($self, $model, @instrument_data) = @_;

    confess "No model to assign instrument data" unless $model and $model->isa('Genome::Model');
    confess "No instrument data to assign to model" unless @instrument_data;
    
    my @instrument_data_assignments;
    for my $instrument_data ( @instrument_data ) {
        my $instrument_data_assignment = $self->create_mock_object(
            class => 'Genome::Model::InstrumentDataAssignment',
            model => $model,
            model_id => $model->id,
            instrument_data => $instrument_data,
            instrument_data_id => $instrument_data->id,
            first_build_id => undef,
        ) or confess;
        push @instrument_data_assignments, $instrument_data_assignment;
    }

    return @instrument_data_assignments;
}

sub create_mock_sanger_instrument_data {
    my ($self , $cnt) = @_;

    $cnt ||= 1;
    my $dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Sanger';

    my @id;
    for my $i (1..$cnt) {
        my $run_name = '0'.$i.'jan00.101amaa';
        my $full_path = $dir.'/'.$run_name;
        confess "Mock instrument data directory ($full_path) does not exist" unless -d $full_path;
        my $id = $self->create_mock_object(
            class => 'Genome::InstrumentData::Sanger',
            id => $run_name,
            run_name => $run_name,
            sequencing_platform => 'sanger',
            seq_id => $run_name,
            sample_name => 'unknown',
            subset_name => 1,
            library_name => 'unknown',
            full_path => $full_path,
        )
            or die "Can't create mock sanger instrument data";
        $id->mock('resolve_full_path', sub{ return $full_path; });
        $id->mock('dump_to_file_system', sub{ return 1; });
        push @id, $id;
    }

    return @id;
}

sub create_mock_solexa_instrument_data {
    my ($self , $cnt) = @_;

    $cnt ||= 1;
    my $dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Solexa';

    my @id;
    my $seq_id = 2338814064;
    for my $i (1..$cnt) {
        my $full_path = $dir.'/'.++$seq_id;
        my $id = $self->create_mock_object(
            class => 'Genome::InstrumentData::Solexa',
            id => $seq_id,
            run_name => '071015_HWI-EAS109_0000_13651',
            sequencing_platform => 'solexa',
            seq_id => $seq_id,
            sample_name => $self->mock_sample_name,
            subset_name => $i,
            library_name => 'H_GV-933124G-S.MOCK-lib1',
            full_path => $full_path,
            read_length => 32,
            is_paired_end => 0,
            lane => $i,
            flow_cell_id => 13651,
        ) or confess "Can't create mock solexa id #$cnt";
        $id->mock('dump_sanger_fastq_files', sub{ return glob($_[0]->full_path.'/*.fastq'); });
        $id->mock('resolve_full_path', sub{ return $full_path; });
        $id->mock('dump_to_file_system', sub{ return 1; });
        $id->mock('total_bases_read', sub{ return '-1, an inaccurate count but true value'; });
        push @id, $id;
    }

    return @id;
}

sub create_mock_454_instrument_data {
    my ($self, $cnt) = @_;
    $cnt ||=1;
    my $dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-454';
    my @id;
    for my $i (1..$cnt) {
	my $fasta_file = $dir.'/Titanium17_2009_05_05_set0.fna';
	my $barcode_file = $dir .'454_Sequencing_log_Titanium_test.txt';
	my $id = $self->create_mock_object (
	    class => 'Genome::InstrumentData::454',
	    library_name => 'Pooled_DNA-2009-03-09_23-lib1',
	    is_paired_end => '0',
	    id => '2772719977',
	    run_name => 'R_2009_03_16_15_08_37_FLX08080419_Administrator_96199846',
	    sample_name => 'Pooled_DNA-2009-03-09_23',
	    seq_id => '2772719977',
	    sequencing_platform => '454',
	) or confess "Unable to create mock 454 id #$cnt";
	$id->mock('fasta_file', sub {return $fasta_file;});
	$id->mock('log_file', sub {return 'mock_test_log';});
	$id->mock('barcode_file', sub {return $barcode_file;});
	push @id, $id;
    }

    return @id;
}

#< Additional Methods for Mock Models Type Names >#
# amplicon assembly
sub _build_subclass_specifics_for_amplicon_assembly { 
    my ($self, $build) = @_;

    $self->mock_methods(
        $build,
        Genome::AmpliconAssembly->helpful_methods,
        (qw/
            amplicon_assembly
            link_instrument_data 
            oriented_fasta_file oriented_qual_file
            processed_fasta_file processed_qual_file
            /),
    );

    return 1;

}

# metagenomic composition 16s 
sub _build_subclass_specifics_for_metagenomic_composition_16s { 
    my ($self, $build) = @_;

    # base
    my @methods = (qw/ 
        description length_of_16s_region
        amplicon_sets amplicon_set_names amplicon_set_for_name _amplicon_iterator_for_name
        sub_dirs _sub_dirs fasta_dir classification_dir amplicon_classifications_dir
        file_base_name
        clean_up

        _fasta_file_for_type_and_set_name
        fasta_and_qual_reader_for_type_and_set_name
        _qual_file_for_type_and_set_name
        fasta_and_qual_writer_for_type_and_set_name

        processed_fasta_file processed_qual_file
        processed_fasta_file_for_set_name processed_qual_file_for_set_name

        classify_amplicons
        classification_file_for_set_name
        classification_file_for_amplicon_name
        
        orient_amplicons
        oriented_fasta_file oriented_qual_file 
        oriented_fasta_file_for_set_name oriented_qual_file_for_set_name

        amplicons_attempted 
        amplicons_processed amplicons_processed_success 
        amplicons_classified amplicons_classified_success
       
        /);

    # sanger
    if ( $build->model->sequencing_platform eq 'sanger' ) {
        push @methods, (qw/

            link_instrument_data

            chromat_dir phd_dir edit_dir
            consed_directory 

            raw_reads_fasta_file raw_reads_qual_file
            processed_reads_fasta_file processed_reads_qual_file
            
            scfs_file_for_amplicon create_scfs_file_for_amplicon
            phds_file_for_amplicon ace_file_for_amplicon
            reads_fasta_file_for_amplicon reads_qual_file_for_amplicon
            
            load_bioseq_for_amplicon

            _get_amplicon_name_for_gsc_read_name
            _get_amplicon_name_for_broad_read_name
            /);
    }
    # 454
    else {
        push @methods, (qw/ amplicon_set_names_and_primers /);
    }

    # mock 'em
    $self->mock_methods($build, @methods);

    # create dirs
    for my $dir ( $build->sub_dirs ) {
        Genome::Utility::FileSystem->create_directory( $build->data_directory."/$dir" )
            or return;
    }

    # metrics
    $build->amplicons_attempted(5);
    $build->amplicons_processed(4);
    $build->amplicons_processed_success( $build->amplicons_processed / $build->amplicons_attempted );
    $build->amplicons_classified(4);
    $build->amplicons_classified_success( $build->amplicons_classified / $build->amplicons_processed );

    return 1;
}

# de novo assembly
sub _build_subclass_specifics_for_de_novo_assembly { 
    my ($self, $build) = @_;

    $self->mock_methods(
        $build,
        (qw/ velvet_fastq_file /),
    );

    return 1;
}

# virome screening
sub _build_subclass_specifics_for_virome_screen {
    my ($self, $build) = @_;

    $self->mock_methods (
        $build,
        (qw/ barcode_file log_file /),
    );
    return 1;
}

# reference alignment
sub _additional_methods_to_reference_alignment_model {
    my ($self, $model) = @_;

    Genome::Utility::TestBase->mock_methods(
        $model,
        (qw/ 
            complete_build_directory 
            _filtered_variants_dir 
            gold_snp_file 
            /)
    );

    return 1;
}

sub _build_subclass_specifics_for_reference_alignment {
    my ($self, $build) = @_;

    if ( $build->model->sequencing_platform eq 'solexa' ) {
        $self->mock_methods(
            $build,
            (qw/ snp_related_metric_directory /),
        );
        $build->mock('_variant_list_files', sub{ return glob($build->snp_related_metric_directory.'/snps_*'); });
    }
    # else { # 454 

    return 1;

}
# TODO?sub _additional_methods_to_reference_alignment_model { 454 and solexa

#< COPY DATA >#
sub copy_test_dir {
    my ($self, $source_dir, $dest) = @_;

    Genome::Utility::FileSystem->validate_existing_directory($dest)
        or confess;

    my $dh = Genome::Utility::FileSystem->open_directory($source_dir)
        or confess;

    while ( my $file = $dh->read ) {
        next if $file =~ m#^\.#;
        # TODO recurse for directories?
        confess "Can't recursively copy directories" if -d $file;
        my $from = "$source_dir/$file";
        File::Copy::copy($from, $dest)
                or die "Can't copy ($from) to ($dest): $!\n";
        }

        return 1;
}

#################################################################
# NEW STUFF - MOVING MOCK OBJECTS INTO THEIR RESPECTIVE MODULES #
#  PUTTING BASE PP MODEL BUILD CREATION HERE                    #
#################################################################

sub get_mock_processing_profile {
    my ($self, %params) = @_;

    Carp::confess("No params to get mock processing profile.") unless %params;
    my $name = delete $params{name};
    Carp::confess("No name to get mock processing profile.") unless $name;
    my $class = delete $params{class};
    Carp::confess("No class to get mock processing profile.") unless $class;
    my $type_name = delete $params{type_name};
    Carp::confess("No type name to get mock processing profile.") unless $type_name;
    
    my $pp = Genome::Utility::TestBase->create_mock_object(
        name => $name,
        class => $class,
        type_name => $type_name,
        %params,
    ) or Carp::confess("Can't get mock $type_name processing profile.");

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

    # Left over params
    Carp::confess("Unknown params for mock $type_name processing profile:\n".Dumper(\%params)) if %params;

    # Stages
    for my $stage ( $pp->stages ) {
        $self->mock_methods(
            $pp,
            $stage.'_objects', $stage.'_job_classes',
        );
    }

    return $pp;
}

sub get_mock_model {
    my ($self, %params) = @_;

    Carp::confess("No params to get mock model.") unless %params;
    my $class = delete $params{class};
    Carp::confess("No class to get mock model.") unless $class;
    my $pp = delete $params{processing_profile};
    Carp::confess("No processing profile to get mock model.") unless $pp;
    # ceate subject
    my $subject = delete $params{subject};
    Carp::confess("No subject to get mock model.") unless $subject;
    
    # Create mock
    my $model = $self->create_mock_object(
        class => 'Genome::Model::'.Genome::Utility::Text::string_to_camel_case($pp->type_name),
        name => 'mr. mock '.$pp->type_name,
        subject_class_name => $subject->class,
        subject_id => $subject->id,
        subject_name => $subject->name,
        subject_type => 'sample_name',
        processing_profile_id => $pp->id,
        data_directory => File::Temp::tempdir(CLEANUP => 1),
    )
        or confess "Can't create mock model ($class)";

    # Methods in base Genome::Model
    $self->mock_methods(
        $model, # added inst data until it gets back into the class def
        (qw/
            instrument_data
            builds_with_status abandoned_builds failed_builds running_builds scheduled_builds
            current_running_build current_running_build_id
            completed_builds last_complete_build last_complete_build_id 
            resolve_last_complete_build _last_complete_build_id 
            succeeded_builds last_succeeded_build last_succeeded_build_id
            compatible_instrument_data assigned_instrument_data unassigned_instrument_data
            /),
    ) or confess "Can't add mock methods to model ($class)";

    return $model;
}

sub get_mock_build {
    my ($self, %params) = @_;

    my $class = delete $params{class};
    Carp::confess("No class given to get mock build.") unless $class;
    my $model = delete $params{model};
    Carp::confess("No model given to get mock build.") unless $model;
    my $data_directory = delete $params{data_directory};
    unless ( $data_directory ) { # TODO use build id??
        $data_directory = $model->data_directory.'/build';
    }

    # Create
    my $build = $self->create_mock_object(
        class => $class,
        model => $model,
        model_id => $model->id,
        data_directory => $data_directory,
        type_name => $model->type_name,
    ) or confess "Can't create mock ".$model->type_name." build";
    mkdir $data_directory unless -d $data_directory;

    # Methods
    $self->mock_methods(
        $build,
        (qw/
            reports_directory resolve_reports_directory
            build_event build_events status
            date_completed date_scheduled
            add_report get_report reports 
            start initialize success fail abandon delete
            metrics
            /),
    ) or confess "Can't add methods to mock build";

    # Inst Data
    $build->mock('instrument_data', sub{ return $_[0]->model->instrument_data; });
    
    # Event
    my $event = $self->create_mock_object(
        class => 'Genome::Model::Event::Build',
        model_id => $build->model_id,
        build_id => $build->id,
        event_type => 'genome model build',
        event_status => 'Succeeded',
        user_name => $ENV{USER},
        date_scheduled => UR::Time->now,
        date_completed => UR::Time->now,
    ) or confess "Can't create mock build event for ".$build->type_name." build";

    $self->mock_methods(
        $event,
        (qw/ desc /),
    ) or confess "Can't add methods to mock build";

    return $build;
}

#######################
# Type Name Test Base #
#######################
# Since models don't have any additional params when creating, we'll test the real methods
#  with a mock model (tester).

# TODO


package Genome::Model::TestBase;

use strict;
use warnings;

#use base 'Genome::Utility::TestBase';
use base 'Test::Class';

use Data::Dumper 'Dumper';
require Scalar::Util;
use Test::More;

sub _model { # the valid model
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
    my ($subclass) = $_[0]->test_class =~ m#Genome::Model::(\w+)#;
    return Genome::Utility::Text::camel_case_to_string($subclass);
}

sub params_for_test_class {
    return Genome::Model::Test->valid_params_for_type_name( $_[0]->type_name );
}

sub test_shutdown : Test(shutdown => 0) {
    my $self = shift;
    
    diag($self->_model->model_link);
    
    return 1;
}


#####################
# Amplicon Assembly #
#####################

package Genome::Model::Test::AmpliconAssembly;

use strict;
use warnings;

use base 'Genome::Model::TestBase';

#######################
# Reference Alignment #
#######################

package Genome::Model::Test::ReferenceAlignment::454;

use strict;
use warnings;

use base 'Genome::Model::TestBase';

package Genome::Model::Test::ReferenceAlignment::Solexa;

use strict;
use warnings;

use base 'Genome::Model::TestBase';

###################################################
###################################################
1;

#$HeadURL$
#$Id$
