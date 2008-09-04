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
    return "-R 'select[model==Intel_Xeon360] span[hosts=1]'";
}

sub should_bsub { 1;}

sub execute {
    my $self = shift;
$DB::single = $DB::stopper;
    my $model = $self->model;
    

    unless($self->revert) {
        $self->error_message("unable to revert...debug ->revert and ->cleanup_mapmerge_i_specify");
        return;
    }

    my $maq_pathname = $self->proper_maq_pathname('genotyper_name');

    my $model_dir = $model->data_directory;

    unless (-d "$model_dir/consensus") {
        mkdir ("$model_dir/consensus");
        chmod 02775, "$model_dir/consensus";
    }

    my ($consensus_file) = $model->assembly_file_for_refseq($self->ref_seq_id);

    my $ref_seq_file = sprintf("%s/all_sequences.bfa", $model->reference_sequence_path);
    #my $ref_seq_file = sprintf("%s/%s.bfa", $model->reference_sequence_path , $self->ref_seq_id);

    my $assembly_opts = $model->genotyper_params || '';

    unless ($model->lock_resource(resource_id=>"assembly_" . $self->ref_seq_id)) {
        $self->error_message("Can't get lock for model's maq assemble output assembly_" . $self->ref_seq_id);
        return undef;
    }
    my $accumulated_alignments_file;
     unless($accumulated_alignments_file = $self->resolve_accumulated_alignments_filename(ref_seq_id=>$self->ref_seq_id, force_use_original_files=>1)) {
         $self->error_message("Couldn't resolve accumulated alignments file");
         return;
    }         

    my @args = ($maq_pathname, 'assemble');
    if ($assembly_opts) {
        push @args, $assembly_opts;
    }
    push @args, ($consensus_file, $ref_seq_file, $accumulated_alignments_file);
    my $cmd = join(' ', @args);
    $self->status_message("Running command: $cmd\n");

    my $rv = system($cmd);
    if ($rv) {
        $self->error_message("nonzero exit code " . $rv/256 . " returned by maq, command looks like, @args");
        return;
    }
    return $self->verify_succesful_completion;
}

sub verify_succesful_completion {
    my $self = shift;

    my ($consensus_file) = $self->model->assembly_file_for_refseq($self->ref_seq_id);
    unless (-e $consensus_file && -s $consensus_file > 20) {
        $self->error_message("Consensus file $consensus_file is too small");
        return;
    }
    return 1;
}

1;

