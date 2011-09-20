package Genome::InstrumentData::Command;
use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command {
    is => 'Command::Tree',
    english_name => 'genome instrument_data command',
    has => [
        instrument_data => { is => 'Genome::InstrumentData', id_by => 'instrument_data_id' },
        instrument_data_id => { is => 'Integer', doc => 'identifies the instrument data by id' },
    ],
    doc => 'Work with instrument data',
};

1;
