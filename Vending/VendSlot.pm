package Vending::VendSlot;

use strict;
use warnings;

use Vending;
class Vending::VendSlot {
    type_name => 'vend slot',
    table_name => 'VEND_SLOT',
    id_by => [
        slot_id => { is => 'integer' },
    ],
    has => [
        machine_id    => { value => 'Vending::Machine', is_constant => 1, is_class_wide => 1,column_name => '' },
        machine       => { is => 'UR::Singleton', id_by => 'machine_id' },

        name          => { is => 'varchar' },
        label         => { is => 'varchar', is_optional => 1 },
        is_buyable    => { is => 'integer' },
        cost_cents    => { is => 'integer', is_optional => 1 },
        items         => { is => 'Vending::VendItem', reverse_id_by => 'slot', is_many => 1 },
        coin_items    => { is => 'Vending::Coin', reverse_id_by => 'slot', is_many => 1 },
        count         => { calculate => q(my @obj = $self->items; 
                                        return scalar(@obj);), 
                         doc => 'How many items are in this slot' },
        content_value => { calculate => q(my @obj = $self->items; 
                                          my $val = 0;
                                          $val += $_->isa('Vending::Coin') ? $_->value_cents : $_->cost_cents foreach @obj;
                                          return $val;), 
                         doc => 'Value of all the items in this slot' },
        content_value_dollars => { calculate_from => 'content_value',
                                   calculate => q(sprintf("\$%.2f", $content_value/100)), 
                                   doc => 'Value of all the contents in dollars' },
        price         => { calculate_from => 'cost_cents',
                         calculate => q(sprintf("\$%.2f", $cost_cents/100)), 
                         doc => 'display price in dollars' },
    ],
    schema_name => 'Machine',
    data_source => 'Vending::DataSource::Machine',
    doc => 'represents a "slot" in the machine, such as "A", "B", "user","change"',
};


&_initialize();

sub _initialize {
    my $a = Vending::VendSlot->get(name => 'change');
    unless ($a) {
        Vending::VendSlot->create(name => 'a', cost_cents => 65, is_buyable => 1);
        Vending::VendSlot->create(name => 'b', cost_cents => 100, is_buyable => 1);
        Vending::VendSlot->create(name => 'c', cost_cents => 150, is_buyable => 1);

        foreach my $name ( qw(bank box change) ) {
print "Creating slot $name\n";
            Vending::VendSlot->create(name => $name, label => '', is_buyable => 0, cost_cents => -1);
        }
    }
}

sub transfer_items_to_slot {
    my($self,$to_slot) =@_;

    my $to_slot_id = $to_slot->id;

    my @objects = $self->items();
    $_->slot_id($to_slot_id) foreach @objects;

    return scalar(@objects);
}

1;
