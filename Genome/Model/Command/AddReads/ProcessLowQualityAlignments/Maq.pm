package Genome::Model::Command::AddReads::ProcessLowQualityAlignments::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;
use Date::Calc;
use File::stat;

class Genome::Model::Command::AddReads::ProcessLowQualityAlignments::Maq {
    is => 'Genome::Model::Event',
};

sub help_brief {
    "Create a new fastq-format file containing reads that aligned poorly in the prior align-reads step";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads process-low-quality-alignments maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}



sub execute {
    my $self = shift;
    
$DB::single = 1;

    my $command = Genome::Model::Command::Tools::UnalignedDataToFastq->create(
                           in => $self->unaligned_reads_file_for_lane(),
                           fastq => $self->unaligned_fastq_file_for_lane(),
                   );
    unless ($command) {
        $self->error_message("Unable to create the UnalignedDataToFastq command");
        return;
    }

    unless ($command->execute()) {
        $self->error_message("UnalignedDataToFastq command execution failed");
        return;
    }

    return 1;
}



1;

