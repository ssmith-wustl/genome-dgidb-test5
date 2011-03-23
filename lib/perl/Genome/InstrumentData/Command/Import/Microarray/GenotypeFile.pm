package Genome::InstrumentData::Command::Import::Microarray::GenotypeFile;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::Import::Microarray::GenotypeFile {
    is  => 'Genome::InstrumentData::Command::Import::Microarray::Base',
};

sub _validate_original_data_path {
    my $self = shift;

    $self->status_message("Validate genotype file");

    my $file = $self->original_data_path;
    if ( not $file ) { 
        $self->error_message("No genotype file given");
        return;
    }

    $self->status_message("Genotype file: $file");

    if ( not -s $file ) {
        $self->error_message("Genotype file ($file) does not exist");
        return;
    }

    # Format, space separated:
    # chr pos alleles
    my $fh = IO::File->new($file, 'r');
    if ( not $fh ) {
        $self->error_message("Cannot open genotype file ($file): $!");
        return;
    }
    my $line = $fh->getline;
    if ( not $line ) {
        $self->error_message();
        return;
    }
    chomp $line;
    my @tokens = split(/\s+/, $line);
    if ( not @tokens or @tokens != 3 ) {
        $self->error_message('Genotype file ($file) is not in 3 column format');
        return;
    }
    $fh->close;

    $self->status_message("Validate genotype file...OK");

    return $file;
}

1;

