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

    my $unaligned_file = $self->unaligned_reads_file_for_lane();
    my $unaligned = IO::File->new($unaligned_file);
    unless ($unaligned) {
        $self->error_message("Unable to open $unaligned_file for reading: $!");
        return;
    }

    my $unaligned_fastq_file = $self->unaligned_fastq_file_for_lane();
    my $fastq = IO::File->new(">$unaligned_fastq_file");
    unless ($fastq) {
        $self->error_message("Unable to open $unaligned_fastq_file for writing: $!");
        return;
    }
  
    while(<$unaligned>) {
        chomp;
        my($read_name,$alignment_quality,$sequence,$read_quality) = split;
        $fastq->print("\@$read_name\n$sequence\n\+\n$read_quality\n");
    }

    $unaligned->close();
    $fastq->close();

    return 1;
}



# The sequence/quality in the unaligned data file is exactly the same
# as in the original fastq file, so we can skip looking up the data in
# the original file
#
# The filehandle passed in here must be from a sorted fastq file,
# and you must ask for read records that are sorted in the same order
sub _get_original_data_for_read_name {
    my($self,$read_name,$fastq_fh) = @_;

    $read_name = "\@$read_name";   # The fastq records still have the @ in the read name (for now)

    while(my $record = $self->get_next_fastq_record($fastq_fh) ) {
        return $record if ($record->{'read_name'} eq $read_name);
    }

    return;
}
    


1;

