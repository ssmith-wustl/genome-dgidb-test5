# FIXME ebelter
#  Long: Remove or update to use inputs as appropriate.
#
package Genome::Model::Command::InstrumentData::DumpToFileSystem;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::InstrumentData::DumpToFileSystem {
    is => 'Genome::Model::Command::InstrumentData',
};

#########################################################

sub help_brief {
    return "Dump model's assigned instrument data to the filesystem";
}

sub help_detail {
    return help_brief();
}

#########################################################

sub execute {
    my $self = shift;

    $self->_verify_model
        or return;

    return $self->model->dump_unbuilt_instrument_data_to_filesysytem;
}

1;

#$HeadURL$
#$Id$
