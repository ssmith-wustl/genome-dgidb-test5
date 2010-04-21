package Genome::InstrumentData::Command::Import::Microarray::Misc;

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Copy::Recursive;
use File::Basename;
use IO::Handle;

class Genome::InstrumentData::Command::Import::Microarray::Misc {
    is  => 'Genome::InstrumentData::Command::Import::Microarray',
    doc => 'create an instrument data for a microarray',
};


sub process_imported_files {
    my $self = shift;
    unless($self->sequencing_platform) {
        $self->sequencing_platform("unknown");
    }
    $self->SUPER::process_imported_files(@_);


    return 1;
}


1;

    


    

