package Genome::Model::Tools::UnalignedDataToFastq;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;

class Genome::Model::Tools::UnalignedDataToFastq {
    is => 'Command',
    has => [
        in => { is => 'String', doc => "Pathname to a file generated from maq map's -u option" },
        fastq => { is => 'String', doc => "pathname of the fastq file to write" },
    ],
};

sub help_brief {
    "Create a new fastq-format file containing reads that aligned poorly in the prior align-reads step";
}

sub help_synopsis {
    return <<"EOS"
    genome-model tools unaligned-data-to-fastq --in /path/to/inputpathname.unaligned --fastq /path/to/data.fastq
EOS
}

sub help_detail {                           
    return <<EOS 
As part of the aligmnent process, the -u option to maq will create a file containing 
reads that had low alignment quailty, or did not align at all.  This command
will take that file and create a fastq-formatted file containing those reads
EOS
}



sub execute {
    my $self = shift;
    
$DB::single = $DB::stopper;

    my $unaligned_file = $self->in();
    my $unaligned = IO::File->new($unaligned_file);
    unless ($unaligned) {
        $self->error_message("Unable to open $unaligned_file for reading: $!");
        return;
    }

    my $unaligned_fastq_file = $self->fastq();
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


# FIXME This should go in a better location later
# returns the next record of data from a fastq filehandle
sub get_next_fastq_record {
    my($self,$fh) = @_;

    my %node;
    my $read_name = $fh->getline;
    return unless $read_name;

    chomp($node{'read_name'} = $read_name);;

    chomp($node{'sequence'} = $fh->getline);
    $fh->getline;  # This should be the read name again, or just a '+'
    chomp($node{'quality'} = $fh->getline);

    return \%node;
}

    


1;

