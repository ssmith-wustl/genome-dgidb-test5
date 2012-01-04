package Genome::ProcessingProfile::RnaSeq;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::RnaSeq {
    is => 'Genome::ProcessingProfile',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    has => [
        subclass_name => { is_mutable => 0,
                           calculate_from => ['sequencing_platform'],
                           calculate => sub {
                                            my($sequencing_platform) = @_;
                                            Carp::confess "No sequencing platform given to resolve subclass name" unless $sequencing_platform;
                                            return 'Genome::ProcessingProfile::RnaSeq::'.Genome::Utility::Text::string_to_camel_case($sequencing_platform);
                                          }
                         },
    ],
    has_param => [
        sequencing_platform => {
            doc => 'The sequencing platform from whence the model data was generated',
            valid_values => ['454', 'solexa'],
        },
        dna_type => {
            doc => 'the type of dna used in the reads for this model',
            valid_values => ['cdna']
        },
        read_aligner_name => {
            doc => 'alignment algorithm/software used for this model',
        },
        read_aligner_version => {
            doc => 'the aligner version used for this model',
            is_optional => 1,
        },
        read_aligner_params => {
            doc => 'command line args for the aligner',
            is_optional => 1,
        },
        expression_name => {
            doc => 'algorithm used to detect expression levels',
            is_optional => 1,
        },
        expression_version => {
            doc => 'the expression detection version used for this model',
            is_optional => 1,
        },
        expression_params => {
            doc => 'the expression detection params used for this model',
            is_optional => 1,
        },
        picard_version => {
            doc => 'the version of Picard to use when manipulating SAM/BAM files',
            is_optional => 1,
        },
        read_trimmer_name => {
            doc => 'trimmer algorithm/software used for this model',
            is_optional => 1,
        },
        read_trimmer_version => {
            doc => 'the trimmer version used for this model',
            is_optional => 1,
        },
        read_trimmer_params => {
            doc => 'command line args for the trimmer',
            is_optional => 1,
        },
        annotation_reference_transcripts => {
            doc => 'The reference transcript set used for splice junction annotation',
            is_optional => 1,
        },
        annotation_reference_transcripts_mode => {
            doc => 'The mode to use annotation_reference_transcripts for expression analysis',
            is_optional => 1,
            valid_values => ['de novo','reference guided','reference only',],
        },
        mask_reference_transcripts => {
            doc => 'The mask level to ignore transcripts located in these annotation features',
            is_optional => 1,
            valid_values => ['rRNA','MT','pseudogene','rRNA_MT','rRNA_MT_pseudogene'],
        },
    ],
};

sub _map_workflow_inputs {
    my $self = shift;
    my $build = shift;

    my @inputs = ();

    push @inputs, build_id => $build->id;

    return @inputs;
}

sub _resolve_workflow_for_build {
    # This is called by Genome::Model::Build::start()
    # Returns a Workflow::Operation
    # By default, builds this from stages(), but can be overridden for custom workflow.
    my $self = shift;
    my $build = shift;
    my $lsf_queue = shift; # TODO: the workflow shouldn't need this yet
    my $lsf_project = shift;

    if (!defined $lsf_queue || $lsf_queue eq '' || $lsf_queue eq 'inline') {
        $lsf_queue = 'apipe';
    }
    if (!defined $lsf_project || $lsf_project eq '') {
        $lsf_project = 'build' . $build->id;
    }

    my $workflow = Workflow::Model->create(
        name => $build->workflow_name,
        input_properties => ['build_id',],
        output_properties => ['coverage_result','expression_result']
    );

    my $log_directory = $build->log_directory;
    $workflow->log_dir($log_directory);


    my $input_connector = $workflow->get_input_connector;
    my $output_connector = $workflow->get_output_connector;

    # Tophat

    my $tophat_operation = $workflow->add_operation(
        name => 'RnaSeq Tophat Alignment',
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => 'Genome::Model::RnaSeq::Command::AlignReads::Tophat',
        )
    );
    
    $tophat_operation->operation_type->lsf_queue($lsf_queue);
    $tophat_operation->operation_type->lsf_project($lsf_project);

    my $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'build_id',
        right_operation => $tophat_operation,
        right_property => 'build_id'
    );

    # RefCov
    my $coverage_operation = $workflow->add_operation(
        name => 'RnaSeq Coverage',
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => 'Genome::Model::RnaSeq::Command::Coverage',
        )
    );
    $coverage_operation->operation_type->lsf_queue($lsf_queue);
    $coverage_operation->operation_type->lsf_project($lsf_project);

    $workflow->add_link(
        left_operation => $tophat_operation,
        left_property => 'build_id',
        right_operation => $coverage_operation,
        right_property => 'build_id'
    );
    

    # Cufflinks
    
    my $cufflinks_operation = $workflow->add_operation(
        name => 'RnaSeq Cufflinks Expression',
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => 'Genome::Model::RnaSeq::Command::Expression::Cufflinks',
        )
    );
    $cufflinks_operation->operation_type->lsf_queue($lsf_queue);
    $cufflinks_operation->operation_type->lsf_project($lsf_project);
    
    $workflow->add_link(
        left_operation => $tophat_operation,
        left_property => 'build_id',
        right_operation => $cufflinks_operation,
        right_property => 'build_id'
    );

    # Define output connector results from coverage and expression
    $workflow->add_link(
        left_operation => $coverage_operation,
        left_property => 'result',
        right_operation => $output_connector,
        right_property => 'coverage_result'
    );
    $workflow->add_link(
        left_operation => $cufflinks_operation,
        left_property => 'result',
        right_operation => $output_connector,
        right_property => 'expression_result'
    );

    return $workflow;
}

sub params_for_alignment {
    my $self = shift;
    my @inputs = @_;

    my $model = $inputs[0]->model;
    my $reference_build = $model->reference_sequence_build;
    my $reference_build_id = $reference_build->id;

    my $read_aligner_params = $self->read_aligner_params || undef;
    my $annotation_reference_transcripts = $self->annotation_reference_transcripts;
    if ($annotation_reference_transcripts) {
        my ($annotation_name,$annotation_version) = split(/\//, $annotation_reference_transcripts);
        my $annotation_model = Genome::Model->get(name => $annotation_name);
        unless ($annotation_model){
            $self->error_message('Failed to get annotation model for annotation_reference_transcripts: ' . $annotation_reference_transcripts);
            return;
        }
        unless (defined $annotation_version) {
            $self->error_message('Failed to get annotation version from annotation_reference_transcripts: '. $annotation_reference_transcripts);
            return;
        }
        my $annotation_build = $annotation_model->build_by_version($annotation_version);
        unless ($annotation_build){
            $self->error_message('Failed to get annotation build from annotation_reference_transcripts: '. $annotation_reference_transcripts);
            return;
        }
        my $gtf_path = $annotation_build->annotation_file('gtf',$reference_build_id);
        unless (defined($gtf_path)) {
            die('There is no annotation GTF file defined for annotation_reference_transcripts build: '. $annotation_reference_transcripts);
        }
        if ($read_aligner_params =~ /-G/) {
            die ('This processing_profile is requesting annotation_reference_transcripts \''. $annotation_reference_transcripts .'\', but there seems to be a GTF file already defined in the read_aligner_params: '. $read_aligner_params);
        }
        if (defined($read_aligner_params)) {
            $read_aligner_params .= ' -G '. $gtf_path;
        } else {
            $read_aligner_params = ' -G '. $gtf_path;
        }
    }
    my %params = (
        instrument_data_id => [map($_->value_id, @inputs)],
        aligner_name => 'tophat',
        reference_build_id => $reference_build_id || undef,
        aligner_version => $self->read_aligner_version || undef,
        aligner_params => $read_aligner_params,
        force_fragment => undef, #unused,
        trimmer_name => $self->read_trimmer_name || undef,
        trimmer_version => $self->read_trimmer_version || undef,
        trimmer_params => $self->read_trimmer_params || undef,
        picard_version => $self->picard_version || undef,
        samtools_version => undef, #unused
        filter_name => undef, #unused
        test_name => $ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef,
    );
    #$self->status_message('The AlignmentResult parameters are: '. Data::Dumper::Dumper(%params));
    my @param_set = (\%params);
    return @param_set;
}

sub _resolve_type_name_for_class {
    return 'rna seq';
}

#< SUBCLASSING >#

sub _resolve_subclass_name_for_sequencing_platform {
    my ($class,$sequencing_platform) = @_;
    my @type_parts = split(' ',$sequencing_platform);
	
    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);
	
    my $class_name = join('::', 'Genome::ProcessingProfile::RnaSeq' , $subclass);
    return $class_name;
}

sub _resolve_sequencing_platform_for_class {
    my $class = shift;

    my ($subclass) = $class =~ /^Genome::ProcessingProfile::RnaSeq::([\w\d]+)$/;
    return unless $subclass;

    return lc join(" ", ($subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx));
    
    my @words = $subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx;
    return lc(join(" ", @words));
}

1;
