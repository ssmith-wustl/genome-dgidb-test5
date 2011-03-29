package Genome::InstrumentData::Command::Import::Microarray::GenotypeFile;

use strict;
use warnings;

use Genome;

require File::Basename;

class Genome::InstrumentData::Command::Import::Microarray::GenotypeFile {
    is  => 'Genome::InstrumentData::Command::Import::Microarray::Base',
};

sub _resolve_unsorted_genotype_file {
    my $self = shift;

    my $original_file = $self->original_data_path;
    if ( not $original_file ) { 
        $self->error_message("No original genotype file given");
        return;
    }
    if ( not -s $original_file ) {
        $self->error_message("Original genotype file ($original_file) does not exist");
        return;
    }
    my $file_basename = File::Basename::basename($original_file);
    my $unsorted_genotype_file = $self->_instrument_data->data_directory.'/'.$file_basename;
    if ( not -s $unsorted_genotype_file ) {
        $self->error_message('Unsorted genotype file does not exist');
        return;
    }
    $self->status_message('Unsorted genotype file: '.$unsorted_genotype_file);

    # Format, space separated: # chr pos alleles
    $self->status_message("Validate unsorted genotype file");
    my $fh = IO::File->new($unsorted_genotype_file, 'r');
    if ( not $fh ) {
        $self->error_message("Cannot open genotype file ($unsorted_genotype_file): $!");
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
    $self->status_message("Validate unsorted genotype file...OK");

    return $unsorted_genotype_file;
}

1;

