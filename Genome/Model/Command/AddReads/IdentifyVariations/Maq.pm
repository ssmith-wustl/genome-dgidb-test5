package Genome::Model::Command::AddReads::IdentifyVariations::Maq;

use strict;
use warnings;

use above "Genome";
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
    my $ref_seq_file = $model->reference_sequence_path . "/" . $self->ref_seq_id . ".bfa";
    unless (-e $ref_seq_file) {
        $self->error_message("reference sequence file $ref_seq_file does not exist.  please verify this first.");
        return;
    }

    my $model_dir = $model->data_directory;

    my $accumulated_alignments_file = $model->resolve_accumulated_alignments_filename(ref_seq_id=>$self->ref_seq_id);
    unless (-f $accumulated_alignments_file) {
        $self->error_message("Alignment file $accumulated_alignments_file was not found.  It should have been created by a prior run of align-reads maq");
        return;
    }
    
    my $analysis_base_path = $model_dir . "/identified_variations";
    unless (-d $analysis_base_path) {
        mkdir($analysis_base_path);
    }

    my $assembly_output_file = sprintf('%s/consensus/%s.cns',
                                       $model_dir, 
                                       (defined $self->ref_seq_id ? $self->ref_seq_id
                                                              : ""));
    
    unless (-f $assembly_output_file) {
        $self->error_message("Assembly output file $assembly_output_file was not found.  It should have been created by a prior run of update-genotype-probabilities maq");
        return;
    }

    my $snp_resource_name = sprintf("snips%s",
                                    defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                              : "");

    my $indel_resource_name = sprintf("indels%s",
                                    defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                              : "");

    unless ($model->lock_resource(resource_id=>$snp_resource_name)) {
        $self->error_message("Can't get lock for model's cns2snp output $snp_resource_name");
        return undef;
    }

    unless ($model->lock_resource(resource_id=>$indel_resource_name)) {
        $self->error_message("Can't get lock for model's cns2snp output $indel_resource_name");
        return undef;
    }

    my $snip_output_file =  $analysis_base_path . "/" . $snp_resource_name;
    my $indel_output_file =  $analysis_base_path . "/" . $indel_resource_name;
                                       
    system("maq cns2snp $assembly_output_file > $snip_output_file");
    
    return (!system("maq indelsoa $ref_seq_file $accumulated_alignments_file > $indel_output_file"));
    
}




1;

