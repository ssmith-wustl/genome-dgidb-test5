package Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype::Samtools;

use strict;
use warnings;

use Genome;
use Command;


class Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype::Samtools {    
    is => ['Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype'],
};


sub help_brief {
    "Use samtools pileup to call consensus"
}

sub help_synopsis {
    return <<"EOS"
    genome model build reference-alignment update-genotype samtools --model-id 5 --ref-seq-id all_sequences
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as reference-alignment solexa pipeline stage 3
EOS
}


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

    my ($consensus_file) = $build->_consensus_files($self->ref_seq_id);
    $consensus_file .= '.samtools_pileup';
    
    my $ref_seq_file = sprintf("%s/all_sequences.fasta", $model->reference_sequence_path);
    my $assembly_opts = $model->genotyper_params || '';

=cut

    unless ($model->lock_resource(resource_id=>'assembly_' . $self->ref_seq_id)) {
        $self->error_message("Can't get lock for model's samtools pileup output assembly_" . $self->ref_seq_id);
        return undef;
    }
    
=cut

    my $maplist_dir = $build->accumulated_alignments_directory;
    my @bam_files = glob("$maplist_dir/".$model->subject_name."*_rmdup.bam");
    unless(@bam_files == 1) {
         $self->error_message("Couldn't resolve accumulated bam file");
         return;
    }         

    my $sam_pathname = '/gscuser/dlarson/samtools/r301wu1/samtools';
    my $cmd = $sam_pathname. " pileup -f $ref_seq_file";
    $cmd .= ' '.$assembly_opts if $assembly_opts;
    
    $cmd = sprintf(
        '%s %s > %s',
        $cmd,
        $bam_files[0],
        $consensus_file,
    );

    $self->status_message("\n***** UpdateGenotype cmd: $cmd *****\n\n");

    $self->shellcmd(
        cmd          => $cmd,
        input_files  => [$ref_seq_file, $bam_files[0]],
        output_files => [$consensus_file],
    );

    return $self->verify_successful_completion;
}


sub verify_successful_completion {
    my $self = shift;

    my ($consensus_file) = $self->build->_consensus_files($self->ref_seq_id);
    $consensus_file .= '.samtools_pileup';

    unless (-e $consensus_file && -s $consensus_file > 20) {
        $self->error_message("Consensus file $consensus_file is too small");
        return;
    }
    return 1;
}

1;

