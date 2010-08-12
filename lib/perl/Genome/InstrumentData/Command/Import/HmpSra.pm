package Genome::InstrumentData::Command::Import::HmpSra;

use strict;
use warnings;
use Genome;

class Genome::InstrumentData::Command::Import::HmpSra {
    is  => 'Command',
    has => [
        path => {},
    ],
};


sub execute {
    my $self = shift;
    
    my $tmp = '/gscuser/jmartin/ttmp'; 
    #my $tmp = Genome::Utility::FileSystem->create_temp_directory();
    $self->status_message("Temp data is in $tmp");

    my $scripts_dir = __FILE__;
    $scripts_dir =~ s/.pm//;
    $self->status_message("Scripts are in: $scripts_dir");    

    return 1;
}

1;

