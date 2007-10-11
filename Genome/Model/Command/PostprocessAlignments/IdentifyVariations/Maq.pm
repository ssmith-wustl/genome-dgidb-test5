package Genome::Model::Command::PostprocessAlignments::IdentifyVariations::Maq;

use strict;
use warnings;

use UR;
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
);

sub help_brief {
    "Use maq to find snips and idels"
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments identify-variation maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the postprocess-alignments process
EOS
}

sub execute {
    my $self = shift;
    
    my $model = Genome::Model->get(id => $self->model_id);

    # ensure the reference sequence exists.
    my $ref_seq_file = $model->reference_sequence_path . "/bfa";
    unless (-e $ref_seq_file) {
        $self->error_message("reference sequence file $ref_seq_file does not exist.  please verify this first.");
        return;
    }

    my $model_dir = $model->data_directory;

    my $accumulated_alignments_file = $model_dir . '/alignments';
    unless (-f $accumulated_alignments_file) {
        $self->error_message("Alignment file $accumulated_alignments_file was not found.  It should have been created by a prior run of align-reads maq");
        return;
    }

    my $assembly_output_file = sprintf('%s/assembly.cns', $model_dir);
    unless (-f $assembly_output_file) {
        $self->error_message("Assembly output file $assembly_output_file was not found.  It should have been created by a prior run of update-genotype-probabilities maq");
        return;
    }

    unless ($model->lock_resource(resource_id=>'snips')) {
        $self->error_message("Can't get lock for model's cns2snp output");
        return undef;
    }

    unless ($model->lock_resource(resource_id=>'indels')) {
        $self->error_message("Can't get lock for model's cns2snp output");
        return undef;
    }

    my $snip_output_file = $model_dir . '/snips';
    system("maq cns2snp $assembly_output_file > $snip_output_file");

    my $indel_file = $model_dir . '/indels';
    
    return (!system("maq indelsoa $ref_seq_file $accumulated_alignments_file > $indel_file"));
    
}

1;

