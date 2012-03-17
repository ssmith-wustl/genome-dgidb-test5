package Genome::Model::ProteinAnnotation;

use strict;
use warnings;
use Genome;
#use PAP;

class Genome::Model::ProteinAnnotation {
    is => 'Genome::ModelDeprecated',
    has => [
        subject => {
            is => 'Genome::Taxon',
            id_by => 'subject_id',
        }
    ],
    has_param => [
        chunk_size => {
            is => 'Number',
            doc => 'Size in bases of fasta chunks',
        },
        annotation_strategy => {
            is => 'Text',
            doc => 'String describing how annotation should be carried out',
        },
    ],
    has_input => [
        prediction_fasta_file => {
            is => 'Genome::File::Fasta',
            doc => 'File containing predicted gene sequences',
        },
        biosql_namespace => {
            is => 'UR::Value::Text',
            is_optional => 1,
            doc => 'when set, uploads results to a biosql database'
        }
    ],
    doc => 'annotate gene predictions'
};

sub _parse_annotation_strategy {
    my $self = shift;

    my $subject = $self->subject;
    my @specs = split(/\s+union\s+/, $self->annotation_strategy);
    
    my @annotator_details;
    for my $spec (@specs) {
        my ($name, $version) = split(/\s+/,$spec); 
        $version = '' if not defined $version;

        my $class_name;
        my @words = split('-', $name);
        
        #$class_name = 'PAP::Command::' . join('', map { ucfirst(lc($_)) } @words);
        $class_name = __PACKAGE__ . '::Command::' . ucfirst(lc(join('',@words)));
        $class_name =~ s/Interproscan/Iprscan/;

        eval { $class_name->class; };
        if ($@) {
            die "error parsing $spec: $name parses to $class_name which has errors: $@";
        }

        unless ($class_name->isa(__PACKAGE__ . '::Command::Annotator')) {
            die "annotator $name maps to module $class_name ...but that does not inherit from "
                . __PACKAGE__ . '::Command::Annotator';
        }
       
        my $requires_chunking = $class_name->requires_chunking;
        #if ($class_name eq 'PAP::Command::PsortB') {  #if ($class_name->_requires_chunked_input) {
        #    $requires_chunking = 1;
        #}
        #else {
        #    $requires_chunking = 0;
        #}

        # the names of the output dirs are similar but not identical on all of the annotator commands :( 
        # TODO: normalize those! (for now we just parse the name)
        # TODO: xfer properties of processing profiles too?
        my $property_name_for_output_dir_on_tool;
        my @properties_from_subject;
        my @p = $class_name->__meta__->properties();
        for my $p ($class_name->__meta__->properties()) {
            next unless $p->can('is_input');
            next unless $p->is_input;
            next if $p->property_name eq 'fasta_file';

            my $property_name = $p->property_name;
            if ($property_name =~ /_archive_dir/ or $property_name eq 'report_save_dir' or $property_name eq 'output_dir') {
                if ($property_name_for_output_dir_on_tool) {
                    die "multiple properties on $class_name seem to be output directories: $property_name_for_output_dir_on_tool, $property_name!";
                }
                $property_name_for_output_dir_on_tool = $property_name;
                next;
            }
            if ($subject->can($property_name) or $property_name eq 'gram_stain') {
                push @properties_from_subject, $property_name;
                next;
            }

            if ($p->is_optional) {
                $self->warning_message("$class_name has input $property_name which is unrecognized, and is being ignored when constructing the workflow.");
            }
            else {
                die "$class_name has input $property_name which is unrecognized, and is not optional!  Cannot construct workflow."
            }
        }
        unless ($property_name_for_output_dir_on_tool) {
            die "failed to find tool output dir name for $class_name: checked " . join(", ", map { $_->property_name } @p) . "\n";
        }

        # TODO: if we allow an annotator to be used more than once in the workflow, how do we name the output dir property?
        my $property_name_for_output_dir_on_workflow = $name . '_output_dir';
        $property_name_for_output_dir_on_workflow =~ s/-/_/g;

        push @annotator_details, {
            name => $name, 
            version => $version, 
            class_name => $class_name, 
            requires_chunking => $requires_chunking,
            property_name_for_output_dir_on_workflow => $property_name_for_output_dir_on_workflow, 
            property_name_for_output_dir_on_tool => $property_name_for_output_dir_on_tool,
            properties_from_subject => \@properties_from_subject
        };
    }

    print Data::Dumper::Dumper(\@annotator_details);
    return @annotator_details;
}
sub _map_workflow_inputs {
    my ($self, $build) = @_;
    my $subject = $self->subject;

    my @details = $self->_parse_annotation_strategy;
    
    my %output_dirs;
    my %subject_properties;
    for my $detail (@details) {
        my $property_name = $detail->{property_name_for_output_dir_on_workflow};
        my $path = join('/', $build->data_directory, $detail->{name});
        $output_dirs{$property_name} = $path;

        # TODO: this should probably be a step, even though it happens to be safe to 
        # do by the time this is called.
        if (not -d $path) {
            if (-d $build->data_directory) {
                Genome::Sys->create_directory($path);
            }
        }

        for my $subject_prop (@{$detail->{properties_from_subject}}) {
            if ($subject_prop eq 'gram_stain') {
                $subject_properties{'gram_stain'} = $subject->gram_stain_category;
            }
            else {
                $subject_properties{$subject_prop} = $subject->$subject_prop;
            }
        }
    }

    # for some reason, passing an undef value to a property on a command fails
    # sadly, we do not currently distinguish between setting undef and not specifying a value
    # if we did, this would need tuning
    # if a command has a default value, you might want to set it to undef to disable that value
    for my $name (keys %subject_properties) {
        my $value = $subject_properties{$name};
        if (!defined($value) or $value eq '') {
            delete $subject_properties{$name};
        }
    }

    my @inputs = (
        prediction_fasta_file => $self->prediction_fasta_file->id,
        chunk_size => $self->chunk_size,
        %output_dirs,
        %subject_properties
    );

    if (my $ns = $build->biosql_namespace) {
        push @inputs, biosql_namespace => $ns;
    }

    print Data::Dumper::Dumper(\@inputs);
    $DB::single = 1;
    return @inputs;
}

sub _resolve_workflow_for_build {
    my ($self, $build, $lsf_queue, $lsf_project) = @_;

    # create the workflow 
    
    my %inputs = $self->_map_workflow_inputs($build);
    my $workflow = Workflow::Model->create(
        name => $build->workflow_name,
        input_properties => [ keys %inputs ],
        output_properties => [ 'all features', ($build->biosql_namespace ? ('upload_complete') : ()) ],
    );
    $workflow->log_dir($build->log_directory);
    my $input_connector = $workflow->get_input_connector;
    my $output_connector = $workflow->get_output_connector;

    # the list of annotators, and the details about them
    # TODO: these keys are a clue as to what the API for a protein annotator should be
    
    my @annotator_details = $self->_parse_annotation_strategy;

    # add one step to split the file if _any_ of the steps require it
    
    my $annotator_count_requiring_chunking = 0;
    for my $detail (@annotator_details) {
        $annotator_count_requiring_chunking++ if $detail->{requires_chunking};
    }
    
    my $fasta_chunker_op;
    if ($annotator_count_requiring_chunking) {
        $fasta_chunker_op = $workflow->add_operation(
            name => 'chunk input sequences',
            operation_type => Workflow::OperationType::Command->create(
                command_class_name => __PACKAGE__ . '::Command::SplitInputs'
            )
        );
        
        $fasta_chunker_op->operation_type->lsf_queue($lsf_queue);
        $fasta_chunker_op->operation_type->lsf_project($lsf_project);

        my $link = $workflow->add_link(
            left_operation => $input_connector,
            left_property => 'chunk_size',
            right_operation => $fasta_chunker_op,
            right_property => 'chunk_size'
        );
        
        $link = $workflow->add_link(
            left_operation => $input_connector,
            left_property => 'prediction_fasta_file',
            right_operation => $fasta_chunker_op,
            right_property => 'fasta_file',
        );
    }

    # add one step for each annotator, coming from either the chunker or the original input
  
    my @detail_props = qw(
        name 
        version 
        class_name 
        requires_chunking
        property_name_for_output_dir_on_workflow 
        property_name_for_output_dir_on_tool
        properties_from_subject
    );
    my @annotator_ops;
    my %name_for_output_feature_list;
    for my $details (@annotator_details) {
        my (
            $name, 
            $version, 
            $class_name, 
            $requires_chunking,
            $property_name_for_output_dir_on_workflow, 
            $property_name_for_output_dir_on_tool,
            $properties_from_subject
        ) = @$details{@detail_props};

        # add a step to the workflow for this annotator
        my $annotator_op = $workflow->add_operation(
            name => $name . ' ' . $version,
            operation_type => Workflow::OperationType::Command->create(
                command_class_name => $class_name,
            ),
            ($requires_chunking ? (parallel_by => 'fasta_file') : ())
        );
        $annotator_op->operation_type->lsf_queue($lsf_queue);
        $annotator_op->operation_type->lsf_project($lsf_project);

        # all annotators run on either the original input fasta, or on each from the chunked input in parallel
        my $link;
        if ($requires_chunking) {
            $link = $workflow->add_link(
                left_operation => $fasta_chunker_op,
                left_property => 'fasta_files',
                right_operation => $annotator_op,
                right_property => 'fasta_file'
            );
        }
        else {
            $link = $workflow->add_link(
                left_operation => $input_connector,
                left_property => 'prediction_fasta_file',
                right_operation => $annotator_op,
                right_property => 'fasta_file'
            );
        }

        # tell the annotator where to put its output
        $link = $workflow->add_link(
            left_operation => $input_connector,
            left_property => $property_name_for_output_dir_on_workflow,
            right_operation => $annotator_op,
            right_property => $property_name_for_output_dir_on_tool, 
        );

        # figure out the name we'll use to pass the generic feature list to a converger
        my $property_name_for_feature_list_inside_workflow = $property_name_for_output_dir_on_workflow;
        $property_name_for_feature_list_inside_workflow =~ s/_output_dir/_feature_list/;
        $name_for_output_feature_list{$annotator_op->id} =  $property_name_for_feature_list_inside_workflow;

        # pass along any other inputs the tool needs which the subject provides
        for my $name (@$properties_from_subject) {
            next unless $inputs{$name};
            my $link = $workflow->add_link(
                left_operation => $input_connector,
                left_property => $name,
                right_operation => $annotator_op,
                right_property => $name, 
            );
        }

        push @annotator_ops, $annotator_op;
    }

    # though the steps above will write out their results to their directory
    # this converges them into one operation to act as a grouping point for whole-set steps
    my $converge_op = $workflow->add_operation(
        name => 'converge results',
        operation_type => Workflow::OperationType::Converge->create(
            input_properties => [sort values %name_for_output_feature_list],
            output_properties => ['all features']
        ),
    );

    for my $annotator_op (@annotator_ops) {
        my $property_name_for_feature_list_inside_workflow = $name_for_output_feature_list{$annotator_op->id};
        my $link = $workflow->add_link(
            left_operation => $annotator_op,
            left_property => 'bio_seq_feature',
            right_operation => $converge_op,
            right_property => $property_name_for_feature_list_inside_workflow,
        );
    }

    # the final feature list is the result
    my $link = $workflow->add_link(
        left_operation => $converge_op,
        left_property => 'all features',
        right_operation => $output_connector,
        right_property => 'all features',
    );

    # upload 
    if ($build->biosql_namespace) {
        my $upload_op = $workflow->add_operation(
            name => 'biosql upload', 
            operation_type => Workflow::OperationType::Command->create(
                command_class_name => __PACKAGE__ . '::Command::UploadResults',
            ),
        );
        $upload_op->operation_type->lsf_queue($lsf_queue);
        $upload_op->operation_type->lsf_project($lsf_project);
        
        $link = $workflow->add_link(
            left_operation => $input_connector,
            left_property => 'biosql_namespace',
            right_operation => $upload_op,
            right_property => 'biosql_namespace' 
        );
         
        $link = $workflow->add_link(
            left_operation => $converge_op,
            left_property => 'all features',
            right_operation => $upload_op,
            right_property => 'bio_seq_features' 
        );

        $link = $workflow->add_link(
            left_operation => $upload_op,
            left_property => 'upload_complete',
            right_operation => $output_connector,
            right_property => 'upload_complete' 
        );
        
        #TODO: after upload, dump to acedb
    }
    else {
        # skip upload
        # TODO: go straight to acedb
    }

    return $workflow;
}

1;

