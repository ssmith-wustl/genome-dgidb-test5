package Genome::Model::ProteinAnnotation;

use strict;
use warnings;
use Genome;
use PAP;
use PAP::Command;

class Genome::Model::ProteinAnnotation {
    is => 'Genome::ModelDeprecated',
    has => [
        subject => {
            is => 'Genome::Taxon',
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
            is => 'FilePath',
            doc => 'File containing predicted gene sequences',
        },
    ],
};

sub _map_workflow_inputs {
    my ($self, $build) = @_;

    my @inputs = ();
    push @inputs,
        fasta_file => $self->prediction_fasta_file,
        chunk_size => $self->chunk_size,
        gram_stain => $self->subject->gram_stain;
}

sub _resolve_workflow_for_build {
    my ($self, $build, $lsf_queue, $lsf_project) = @_;

    # figure out the list of tools, and which ones, if any, need to run on chunked output
    # TODO: replace with a parser
    my @specs = split(/\s+union\s+/, $self->annotation_strategy);
    my $subject = $build->model->subject;
    my @annotator_details;
    my @output_subdirs;
    my $annotator_count_requiring_chunking = 0;
    for my $spec (@specs) {
        my ($name, $version) = split(/\s+/,$spec); 
        
        my $class_name;
        my @words = split('-', $name);
        $class_name = 'PAP::Command::' . join('', map { ucfirst(lc($_)) } @words);
        eval { $class_name->class; };
        if ($@) {
            die "error parsing $spec: $name parses to $class_name which has errors: $@";
        }
       
        my $requires_chunking;
        if ($class_name eq 'PAP::Command::PSortB') {  #if ($class_name->_requires_chunked_input) {
            $requires_chunking = 1;
            $annotator_count_requiring_chunking++;
        }
        else {
            $requires_chunking = 0;
        }

        # the names of the output dirs are similar but not identical on all of the annotator commands :( 
        # TODO: normalize those! (for now we just parse the name)
        # TODO: xfer properties of processing profiles too?
        my $property_name_for_output_dir_on_tool;
        my @properties_from_subject;
        for my $p ($class_name->__meta__->properties()) {
            next unless $p->can('is_input');
            next unless $p->is_input;
            next if $p->property_name eq 'fasta_file';

            my $property_name = $p->property_name;
            if ($property_name =~ /_archive_dir/) {
                if ($property_name_for_output_dir_on_tool) {
                    die "multiple properties on $class_name seem to be output directories: $property_name_for_output_dir_on_tool, $property_name!";
                }
                $property_name_for_output_dir_on_tool = $property_name;
                next;
            }
            if ($subject->can($property_name)) {
                push @properties_from_subject, $property_name;
                next;
            }

            if ($p->is_optional) {
                $self->warning_message("$class_name has input $property_name which is unrecognized, and is being ignored when construction the workflow.");
            }
            else {
                die "$class_name has input $property_name which is unrecognized, and is not optional!"
            }
        }

        # TODO: if we allow an annotator to be used more tha once in the workflow, how do we name the output dir property?
        my $property_name_for_output_dir_on_workflow = $name . '_output_dir';

        push @annotator_details, [
            $name, 
            $version, 
            $class_name, 
            $requires_chunking,
            $property_name_for_output_dir_on_workflow, 
            $property_name_for_output_dir_on_tool,
            \@properties_from_subject
        ];
        push @output_subdirs, $property_name_for_output_dir_on_workflow;
    }

    # create the workflow 

    my $workflow = Workflow::Model->create(
        name => $build->workflow_name,
        input_properties => [
            'chunk_size',
            'prediction_fasta_file',
            @output_subdirs,            # sadly, the workflow doesn't support embedding constant inputs/params for ops
        ],
        output_properties => ['bio_seq_features'],
    );

    my $input_connector = $workflow->get_input_connector;
    my $output_connector = $workflow->get_output_connector;

    # add one step to split the file if _any_ of the steps require it

    my $fasta_chunker_op;
    if ($annotator_count_requiring_chunking) {
        $fasta_chunker_op = $workflow->add_operation(
            name => 'chunk input sequences',
            operation_type => Workflow::OperationType::Command->create(
                command_class_name => 'PAP::FastaChunker',
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
   
    my @annotator_ops;
    for my $details (@annotator_details) {
        my (
            $name, 
            $version, 
            $class_name, 
            $requires_chunking,
            $property_name_for_output_dir_on_workflow, 
            $property_name_for_output_dir_on_tool,
            $properties_from_subject
        ) = @$details;

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

        # pass along any other inputs the tool needs which the subject provides
        for my $name (@$properties_from_subject) {
            my $link = $workflow->add_link(
                left_operation => $input_connector,
                left_property => $name,
                right_operation => $annotator_op,
                right_property => $name, 
            );
        }

        push @annotator_ops, $annotator_op;
    }

    # **************** Brian: this part is not complete by any meanys (and the above is untested)...*********************** 

    # though the steps above will write out their results to their directory
    # this converges them into one operation to act as a grouping point for whole-set steps
    my $converge_op = $workflow->add_operation(
        name => 'converge results',
        operation_type => Workflow::OperationType::Converge->create(
            input_properties => ['bio_seq_feature'],
            output_properties => ['bio_seq_features']
        ),
    );
    $converge_op->operation_type->lsf_queue($lsf_queue);
    $converge_op->operation_type->lsf_project($lsf_project);

    for (@annotator_ops) {
        # link to the converger above
    }

    # now link the converge_op to the output_connector...

    # done!

    return $workflow;
}

1;

