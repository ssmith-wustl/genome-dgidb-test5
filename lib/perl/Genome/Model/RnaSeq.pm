package Genome::Model::RnaSeq;

# these modules no longer exist as physical files in the repo
# this code will prevent them from being loaded from another part of @INC
# it can be removed after this snapshot becomes stable...
for my $f (qw|
    Genome/Model/Build/RnaSeq.pm
    Genome/Model/Command/Define/RnaSeq.pm
    Genome/ProcessingProfile/RnaSeq.pm
|) {
    $INC{$f} = 1;
}

use strict;
use warnings;

use Genome;
use version;

class Genome::Model::RnaSeq {
    is => 'Genome::ModelDeprecated',
    has => [
        subject                      => { is => 'Genome::Sample', id_by => 'subject_id' },
        processing_profile => { is => 'Genome::ProcessingProfile', id_by => 'processing_profile_id', },
        # TODO: Possibly remove accessor
        reference_sequence_build_id  => { via => 'reference_sequence_build', to => 'id' },
        reference_sequence_name      => { via => 'reference_sequence_build', to => 'name' },
    ],
    has_input => [
        reference_sequence_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
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
    doc => 'A genome model produced by aligning cDNA reads to a reference sequence.',
};


sub compatible_instrument_data {
    my $self = shift;
    my %params;
    my @compatible_instrument_data = $self->SUPER::compatible_instrument_data(%params);
    return grep{!($_->can('is_paired_end')) or $_->is_paired_end} @compatible_instrument_data;
}

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

    my $reference_build = $self->reference_sequence_build;
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

        # Test to see if this is version 1.4.0 or greater
        if (version->parse($self->read_aligner_version) >= version->parse('1.4.0')) {
            my $transcriptome_index_prefix = $annotation_build->annotation_file('',$reference_build_id);
            unless (-s $transcriptome_index_prefix .'.fa') {
                # TODO: We should probably lock until the first Tophat job completes creating the transriptome index
            }
            $read_aligner_params .= ' --transcriptome-index '. $transcriptome_index_prefix;
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

# these must stay in place until:
# 1 old snapshots complete any running builds
# 2 the database is updated to not have these class names anymore

#class Genome::ProcessingProfile::RnaSeq::Solexa {
#    is => 'Genome::ProcessingProfile::RnaSeq'
#};
#
#class Genome::Model::Build::RnaSeq::Solexa {
#    is => 'Genome::Model::Build::RnaSeq'
#};

sub Genome::ProcessingProfile::Command::List::RnaSeq::_resolve_boolexpr {
    my $self = shift;

    my ($bool_expr, %extra) = UR::BoolExpr->resolve_for_string(
        'Genome::ProcessingProfile', #$self->subject_class_name,
        $self->_complete_filter, 
        $self->_hint_string,
        $self->order_by,
    );

    $self->error_message( sprintf('Unrecognized field(s): %s', join(', ', keys %extra)) )
        and return if %extra;

    print "$bool_expr\n";
    $bool_expr = $bool_expr->add_filter(
        type_name => ['rna seq']
    );
    print "$bool_expr\n";

    return $bool_expr;
}

1;

