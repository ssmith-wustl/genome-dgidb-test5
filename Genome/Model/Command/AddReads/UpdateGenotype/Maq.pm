package Genome::Model::Command::AddReads::UpdateGenotype::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;


class Genome::Model::Command::AddReads::UpdateGenotype::Maq {    
    is => ['Genome::Model::Command::AddReads::UpdateGenotype', 'Genome::Model::Command::MaqSubclasser'],
};

sub help_brief {
    "Use maq to build the mapping assembly"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads update-genotype maq --model-id 5 --ref-seq-id all_sequences
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub bsub_rusage {
    return "-R 'select[type=LINUX64] span[hosts=1]'";

}

sub should_bsub { 1;}

sub execute {
    my $self = shift;

    my $model = Genome::Model->get(id => $self->model_id);
    my $maq_pathname = $self->proper_maq_pathname('genotyper_name');

    my $model_dir = $model->data_directory;

    unless (-d "$model_dir/consensus") {
        mkdir ("$model_dir/consensus");
    }

    my $assembly_output_file = $model->assembly_file_for_refseq($self->ref_seq_id);

    my $ref_seq_file = sprintf("%s/%s.bfa", $model->reference_sequence_path , $self->ref_seq_id);

    my $assembly_opts = $model->genotyper_params || '';

    unless ($model->lock_resource(resource_id=>"assembly_" . $self->ref_seq_id)) {
        $self->error_message("Can't get lock for model's maq assemble output assembly_" . $self->ref_seq_id);
        return undef;
    }
    my $accumulated_alignments_file = $model->resolve_accumulated_alignments_filename(ref_seq_id=>$self->ref_seq_id);

    my @args = ($maq_pathname, 'assemble');
    if ($assembly_opts) {
        push @args, $assembly_opts;
    }
    push @args, ($assembly_output_file, $ref_seq_file, $accumulated_alignments_file);
    print "@args\n";

    my $rv = system(@args);
    if ($rv) {
        $self->error_message("nonzero exit code $rv returned by maq, command looks like, @args");
        return;
    }
    return 1;
}

1;

