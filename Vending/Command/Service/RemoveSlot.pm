package Vending::Command::Service::RemoveSlot;
use strict;
use warnings;

use Vending;
class Vending::Command::Service::RemoveSlot {
    is => ['Vending::Command::Outputter', 'Vending::Command::Service'],
    doc => 'Uninstall the named slot and remove all the items',
    has => [
        name => { is => 'String', doc => 'Name of the slot to empty out' },
    ], 
};


sub _get_items_to_output {
    my $self = shift;
    my $machine = $self->machine();

    my @items = $machine->empty_slot_by_name($self->name);

    my $slot = $machine->slots(name => $self->name);
    $slot->delete;

    return @items;
}
1;

