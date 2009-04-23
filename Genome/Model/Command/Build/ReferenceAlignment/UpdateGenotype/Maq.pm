package Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype::Maq;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;


class Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype::Maq {
    is => ['Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype'],
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

sub should_bsub { 1;}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    my $model = $self->model;
    my $build = $self->build;

    unless($self->revert) {
        $self->error_message("unable to revert...debug ->revert and ->cleanup_mapmerge_i_specify");
        return;
    }

    my $maq_pathname = $build->path_for_maq_version('genotyper_version');
    my $consensus_dir = $build->consensus_directory;
    unless (-d $consensus_dir) {
        unless (Genome::Utility::FileSystem->create_directory($consensus_dir)) {
            $self->error_message("Failed to create consensus directory $consensus_dir:  $!");
            return;
        }
    }
    
    my ($consensus_file) = $build->_consensus_files($self->ref_seq_id);
    #assuming the ref_seq_id (above) is 'all_sequences', if not, use line below.
    #my ($consensus_file) = $build->_consensus_files("all_sequences");

    my $ref_seq_file = sprintf("%s/all_sequences.bfa", $model->reference_sequence_path);
    #my $ref_seq_file = sprintf("%s/%s.bfa", $model->reference_sequence_path , $self->ref_seq_id);

    my $assembly_opts = $model->genotyper_params || '';

    unless ($model->lock_resource(resource_id=>"assembly_" . $self->ref_seq_id)) {
        $self->error_message("Can't get lock for model's maq assemble output assembly_" . $self->ref_seq_id);
        return undef;
    }
    my $accumulated_alignments_file;
    #unless ($accumulated_alignments_file = $build->resolve_accumulated_alignments_filename(ref_seq_id=>$self->ref_seq_id)) {
    unless ($accumulated_alignments_file = $build->resolve_accumulated_alignments_filename() ) {
         $self->error_message("Couldn't resolve accumulated alignments file");
         return;
    }

    my $cmd = $maq_pathname .' assemble '. $assembly_opts .' '. $consensus_file .' '. $ref_seq_file .' '. $accumulated_alignments_file;
    $self->status_message("\n************* UpdateGenotype cmd: $cmd *************************\n\n");
    $self->shellcmd(
                    cmd => $cmd,
                    input_files => [$ref_seq_file,$accumulated_alignments_file],
                    output_files => [$consensus_file],
                );

    unlink $accumulated_alignments_file;

    return $self->verify_successful_completion;
}

sub verify_successful_completion {
    my $self = shift;

    my ($consensus_file) = $self->build->_consensus_files($self->ref_seq_id);
    unless (-e $consensus_file && -s $consensus_file > 20) {
        $self->error_message("Consensus file $consensus_file is too small");
        return;
    }
    return 1;
}

1;

