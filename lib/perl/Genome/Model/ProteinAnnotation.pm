package Genome::Model::ProteinAnnotation;

use strict;
use warnings;
use Genome;

class Genome::Model::ProteinAnnotation {
    is => 'Genome::Model',
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

    my $workflow = Workflow::Model->create(
        name => $build->workflow_name,
        input_properties => ['chunk_size','prediction_fasta_file'],
        output_properties => [],
    );

    my $input_connector = $workflow->get_input_connector;
    my $output_connector = $workflow->get_output_connector;

    # One step to split the file
    
    my $fasta_chunker_operation = $workflow->add_operation(
        name => 'Split Inputs',
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => 'PAP::FastaChunker',
        )
    );
    
    $fasta_chunker_operation->operation_type->lsf_queue($lsf_queue);
    $fasta_chunker_operation->operation_type->lsf_project($lsf_project);

    my $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'chunk_size',
        right_operation => $fasta_chunker_operation,
        right_property => 'chunk_size'
    );
    
    my $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'prediction_fasta_file',
        right_operation => $fasta_chunker_operation,
        right_property => 'fasta_file',
    );

    # Then run each tool.
    # TODO: replace with a parser
    my @specs = split(/\s+union\s+/, $self->annotation_strategy);
    for my $spec (@specs) {
        my ($name, $version) = split(/\s+/,$spec); 
        my @words = split('-', $name);
        my $class_name = 'PAP::Command::' . join('', map { ucfirst(lc($_)) } @words);
        eval { 
            $class_name->class;
        };
        if ($@) {
            die "error parsing $spec: $name parses to $class_name which has errors: $@";
        }
        
        #if ($class_name->_requires_chunked_input) {
        if ($class_name eq 'PAP::Command::PSortB') {

        }
        else {

        }
    }



1;

