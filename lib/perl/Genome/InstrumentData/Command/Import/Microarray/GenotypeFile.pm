package Genome::InstrumentData::Command::Import::Microarray::GenotypeFile;

use strict;
use warnings;

use Genome;

require File::Basename;

class Genome::InstrumentData::Command::Import::Microarray::GenotypeFile {
    is => 'Genome::InstrumentData::Command::Import::Microarray::Base',
    has => [
        genotype_file => { 
            is => 'Text', 
            is_optional => 1,
            doc => 'The genotype file. Only needed if importing a directory, otherwise, the original data path will be the genotype file.', 
        },
    ],
    doc => 'import microarray data with a genotype file',
};

sub _resolve_unsorted_genotype_file {
    my $self = shift;

    $self->status_message("Resolve unsorted genotype file");

    my $unsorted_genotype_file;
    if ( $self->genotype_file ) {
        $unsorted_genotype_file = $self->_instrument_data->data_directory.'/'.File::Basename::basename($self->genotype_file);
        $self->_copy_file($self->genotype_file) if not -s $unsorted_genotype_file;
    }
    else {
        $unsorted_genotype_file = $self->_instrument_data->data_directory.'/'.File::Basename::basename($self->original_data_path);
    }

    if ( not -s $unsorted_genotype_file ) {
        $self->error_message("Could not find unsorted genotype file: $unsorted_genotype_file");
        return;
    }
    $self->status_message('Unsorted genotype file: '.$unsorted_genotype_file);

    $self->status_message("Validate unsorted genotype file");
    my $fh = IO::File->new($unsorted_genotype_file, 'r');
    if ( not $fh ) {
        $self->error_message("Cannot open genotype file ($unsorted_genotype_file): $!");
        return;
    }
    my $line = $fh->getline;
    chomp $line;
    my @tokens = split(/\s+/, $line);
    # Format, space separated: # chr pos alleles
    if ( not @tokens or @tokens != 3 ) {
        $self->error_message('Genotype file ($file) is not in 3 column format');
        return;
    }
    $fh->close;
    $self->status_message("Validate unsorted genotype file...OK");

    $self->status_message("Resolve unsorted genotype file...OK");

    return $unsorted_genotype_file;
}

1;

