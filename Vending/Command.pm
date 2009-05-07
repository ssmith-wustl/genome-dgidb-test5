package Vending::Command;
use strict;
use warnings;

use Vending;

class Vending::Command {
    is => 'Command',
    has => [
         machine_id => { value => 'Vending::Machine', is_constant => 1, is_class_wide => 1 },
         machine    => { is => 'Vending::Machine', id_by => 'machine_id' },
    ],
};

#sub machine {
#    my $machine = Vending::Machine->get();
#    return $machine;
#}

1;
