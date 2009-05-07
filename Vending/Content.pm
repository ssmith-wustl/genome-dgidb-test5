package Vending::Content;
use strict;
use warnings;
use Vending;

class Vending::Content {
    type_name => 'vend item',
    table_name => 'content',
    is_abstract => 1,
    sub_classification_method_name => 'type_name_resolver',
    id_by => [
        vend_item_id => { is => 'integer' },
    ],
    has => [
        machine_id => { value => 'Vending::Machine', is_constant => 1, is_class_wide => 1, column_name => '' },
        machine    => { is => 'Vending::Machine', id_by => 'machine_id' },

        type_name => { is => 'varchar', is_optional => 1 },
        slot      => { is => 'Vending::VendSlot', id_by => 'slot_id' },
        slot_name => { via => 'slot', to => 'name' },
    ],
    schema_name => 'Machine',
    data_source => 'Vending::DataSource::Machine',
};

# Called when you try to create a generic Vending::Content
sub type_name_resolver {
    my $class = shift;

    my %params;
    if (ref($_[0])) {
        %params = %{$_[0]};  # Called with obj as arg
    } else {
        %params = @_;        # called with hash as arglist
    }
    return $params{'type_name'};
}
    

# Turn this thing into a Vending::ReturnedItem to give back to the user
# as a side effect, $self is deleted
sub dispense {
    my $self = shift;

    my @items_to_dispense;
    if (ref($self)) {
        # object method...
        @items_to_dispense = ($self);
    } else {
        # Class method
        @items_to_dispense = @_;
    }
    return Vending::ReturnedItem->create_from_vend_items(@items_to_dispense);
}

1;
