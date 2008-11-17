package Genome::InstrumentData::Command;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command {
    is => 'Command',
    is_abstract => 1,
    english_name => 'genome instrument_data command',
    has => [
    instrument_data => { is => 'Genome::InstrumentData', id_by => 'instrument_data_id' },
    instrument_data_id => { is => 'Integer', doc => 'identifies the instrument data by id' },
    ],
};

############################################

sub help_brief {
    return 'Operations for instrument data';
}

############################################

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome instrument-data';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'instrument-data';
}

############################################

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    unless ( $self->processing_profile ) {
        $self->error_message("A processing profile (by id or name) is required for this command");
        return;
    }

    return $self;
}

1;

#$HeadURL$
#$Id$
