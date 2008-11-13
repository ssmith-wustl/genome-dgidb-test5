package Genome::Model::Command::InstrumentData;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::InstrumentData {
    is => 'Genome::Model::Command',
    is_abstract => 1,
};

sub help_brief {
    return "Operations for model's instrument data";
}

sub help_detail {
    return hlpe_brief();
}

1;

#$HeadURL$
#$Id$
