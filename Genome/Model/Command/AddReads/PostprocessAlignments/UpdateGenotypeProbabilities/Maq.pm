package Genome::Model::Command::AddReads::PostprocessAlignments::UpdateGenotypeProbabilities::Maq;

use strict;
use warnings;

use UR;
use Command;
use Genome::Model;
use File::Path;
use File::Basename;
use Data::Dumper;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
);

sub help_brief {
    "Use maq to build the mapping assembly"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads update-genotype-probabilities maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub execute {
    my $self = shift;

    my $model = Genome::Model->get(id => $self->model_id);

    my $model_dir = $model->data_directory;

    my $accumulated_alignments_file = $model->resolve_accumulated_alignments_filename(ref_seq_id=>$self->ref_seq_id);
    unless (-f $accumulated_alignments_file) {
        $self->error_message("Alignments file $accumulated_alignments_file was not found.  It should have been created by a prior run of align-reads maq");
        return;
    }

    unless (-d "$model_dir/consensus") {
        mkdir ("$model_dir/consensus");
    }

    my $assembly_output_base = sprintf('consensus/%s.cns', $self->ref_seq_id);
    my $assembly_output_file = $model_dir . "/" . $assembly_output_base;
    my $ref_seq_file = sprintf("%s/%s.bfa", $model->reference_sequence_path , $self->ref_seq_id);


    my $assembly_opts = $model->genotyper_params || '';

    unless ($model->lock_resource(resource_id=>$assembly_output_base)) {
        $self->error_message("Can't get lock for model's maq assemble output $assembly_output_base");
        return undef;
    }
    my $scmd = "maq assemble $assembly_opts $assembly_output_file $ref_seq_file $accumulated_alignments_file";
    print $scmd, "\n";
    return (!system($scmd));
    
}

1;

