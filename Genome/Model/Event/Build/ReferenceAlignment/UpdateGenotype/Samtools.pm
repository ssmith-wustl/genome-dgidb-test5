package Genome::Model::Event::Build::ReferenceAlignment::UpdateGenotype::Samtools;


#REVIEW fdu
#Currently this module doesn't have any process inside. It's
#originally created to generate disk-space consuming samtools
#pileup file, but turned off later on. We need either ask MG to throw
#some useful process here or remove this (also skip this
#UpdateGenotype step in variant_detection stage for bwa-sam
#based build)



use strict;
use warnings;

use File::Spec;
use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::UpdateGenotype::Samtools {    
    is => ['Genome::Model::Event::Build::ReferenceAlignment::UpdateGenotype'],
};

sub execute {
    my $self = shift;
    $DB::single = $DB::stopper;
    
    my $model = $self->model;
    my $build = $self->build;
    
    unless($self->revert) {
        $self->error_message("unable to revert...debug ->revert and ->cleanup_mapmerge_i_specify");
        return;
    }

    my $consensus_dir = $build->consensus_directory;
    unless (-d $consensus_dir) {
        unless ($self->create_directory($consensus_dir)) {
            $self->error_message("Failed to create consensus directory $consensus_dir: $!");
            return;
        }
    }

    my $consensus_file = $build->bam_pileup_file_path;   
 
    my $ref_seq_file = File::Spec->catfile($model->reference_build->data_directory, 'all_sequences.fasta');
    my $assembly_opts = $model->genotyper_params || '';

=cut

    unless ($model->lock_resource(resource_id=>'assembly_' . $self->ref_seq_id)) {
        $self->error_message("Can't get lock for model's samtools pileup output assembly_" . $self->ref_seq_id);
        return undef;
    }
    
=cut

    my $maplist_dir = $build->accumulated_alignments_directory;
    my $bam_file = $build->whole_rmdup_bam_file;         

    my $sam_pathname = Genome::Model::Tools::Sam->path_for_samtools_version($model->genotyper_version);
    my $cmd = $sam_pathname. " pileup -f $ref_seq_file";
    $cmd .= ' '.$assembly_opts if $assembly_opts;
    
    $cmd = sprintf(
        '%s %s > %s',
        $cmd,
        $bam_file,
        $consensus_file,
    );

    #$self->status_message("\n***** UpdateGenotype cmd: $cmd *****\n\n");
    $self->status_message("\n***** Due to disk space and speed issue. For now turn off UpdateGenotype cmd: $cmd *****\n\n");

=cut

    $self->shellcmd(
        cmd          => $cmd,
        input_files  => [$ref_seq_file, $bam_file],
        output_files => [$consensus_file],
    );

    return $self->verify_successful_completion;

=cut
    return 1;
}


sub verify_successful_completion {
    my $self = shift;

    my $consensus_file = $self->build->bam_pileup_file_path;
    
=cut

    unless (-e $consensus_file && -s $consensus_file > 20) {
        $self->error_message("Consensus file $consensus_file is too small");
        return;
    }
    
=cut

    return 1;
}

1;

