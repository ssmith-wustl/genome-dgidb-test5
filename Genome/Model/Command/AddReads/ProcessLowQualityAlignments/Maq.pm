package Genome::Model::Command::AddReads::ProcessLowQualityAlignments::Maq;

use strict;
use warnings;
use Genome;

class Genome::Model::Command::AddReads::ProcessLowQualityAlignments::Maq {
    is => 'Genome::Model::Command::AddReads::ProcessLowQualityAlignments',
};

sub help_brief {
    'Create a new fastq-format file containing reads that aligned poorly in the prior align-reads step';
}

sub help_synopsis {
    'genome-model add-reads process-low-quality-alignments maq --model-id 5 --run-id 10'
}

sub help_detail {
    'Turn the unaligned reads from the alignment step into a fastq for use by other pipelines.'
}

sub execute {
    my $self = shift;
    $DB::single = $DB::stopper;
    
    my $alignment_event = $self->prior_event;
    my $unaligned_reads_file = $alignment_event->unaligned_reads_file;
    
    my @unaligned_reads_files;
    if (-s $unaligned_reads_file) {
        my $command = Genome::Model::Tools::Maq::UnalignedDataToFastq->execute(
            in => $unaligned_reads_file, 
            fastq => $unaligned_reads_file . '.fastq' 
        );
        unless ($command) {die "Failed Genome::Model::Tools::Maq::UnalignedDataToFastq for $unaligned_reads_file";}
    } 
    else {
        @unaligned_reads_files = $alignment_event->unaligned_reads_files; 
        foreach my $unaligned_reads_files_entry (@unaligned_reads_files){
            my $command = Genome::Model::Tools::Maq::UnalignedDataToFastq->execute(
                in => $unaligned_reads_files_entry, 
                fastq => $unaligned_reads_files_entry . '.fastq'
            );
        unless ($command) {die "Failed Genome::Model::Tools::Maq::UnalignedDataToFastq for $unaligned_reads_files_entry";}
        }
    }
    unless (-s $unaligned_reads_file || @unaligned_reads_files) {
        $self->error_message("Failed to verify successful completion!");
        return;
    }

    #unless ($self->verify_successful_completion) {
    #    $self->error_message("Failed to verify successful completion!");
    #    return;
    #}

    return 1;
}


sub verify_successful_completion {
    my $self = shift;
    my $alignment_event = $self->prior_event;
    my $unaligned_reads_file = $alignment_event->unaligned_reads_file;
    my $unaligned_reads_fastq = $unaligned_reads_file . '.fastq';
    unless (-e $unaligned_reads_fastq) {
        $self->error_message("Failed to find file $unaligned_reads_fastq!");
        return;
    }
    return 1;
}

1;
