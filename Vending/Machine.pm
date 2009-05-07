package Vending::Machine;

use strict;
use warnings;

use Vending;

class Vending::Machine {
    is => 'UR::Singleton',
    doc => 'Represents the vending machine',
    has_many => [
        products        => { is => 'Vending::Product', reverse_id_by => 'machine', is_many => 1 },
        items           => { is => 'Vending::Content', reverse_id_by => 'machine', is_many => 1 },
        inventory_items => { is => 'Vending::Inventory', reverse_id_by => 'machine', is_many => 1 },
        item_types      => { is => 'Vending::ContentType', reverse_id_by => 'machine', is_many => 1 },
        slots           => { is => 'Vending::VendSlot', reverse_id_by => 'machine', is_many => 1,},
    ],
    has => [
        coin_box_slot => { via => 'slots', to => '-filter', where => [name => 'box'] },
        bank_slot     => { via => 'slots', to => '-filter', where => [name => 'bank'] },
        change_slot   => { via => 'slots', to => '-filter', where => [name => 'change'] },
    ],
};


# Insert a coin
sub insert {
    my($self, $item_name) = @_;

    my $coin_type = Vending::CoinType->get(name => $item_name);
    unless ($coin_type) {
        $self->error_message("This machine does not accept '$item_name' coins");
        return;
    }

    my $slot = $self->coin_box_slot();
    my $coin = $slot->add_item(type_name => 'Vending::Coin', type_id => $coin_type->type_id);

    return defined($coin);
}

sub coin_return {
    my $self = shift;

    my $slot = $self->coin_box_slot;
    my @coins = $slot->items();
    my @returned_items = Vending::ReturnedItem->create_from_vend_items(@coins);

    return @returned_items;
}

sub empty_bank  {
    my $self = shift;

    my $slot = $self->bank_slot();
    my @coins = $slot->items();
    my @returned_items = Vending::ReturnedItem->create_from_vend_items(@coins);

    return @returned_items;
}

sub empty_slot_by_name {
    my($self,$name) = @_;

    my $slot = $self->slots(name => $name);
    return unless $slot;
    unless ($slot->is_buyable) {
        die "You can only empty out inventory type slots";
    }

    my @items = $slot->items();
    my @returned_items = Vending::ReturnedItem->create_from_vend_items(@items);

    return @returned_items;
}




sub buy {
    my($self,@slot_names) = @_;
    
    my $coin_box = $self->coin_box_slot();
    my $transaction = UR::Context::Transaction->begin();

$DB::single = 1;
    my @returned_items = eval {

        my $users_money = $coin_box->content_value();

        my @bought_items;
        my %iterator_for_slot;

        foreach my $slot_name ( @slot_names ) {
            my $vend_slot = $self->slots(name => $slot_name);
            unless ($vend_slot && $vend_slot->is_buyable) {
                die "$slot_name is not a valid choice\n";
            }

            my $iter = $iterator_for_slot{$slot_name} || $vend_slot->item_iterator();
            unless ($iter) {
                die "Problem creating iterator for $slot_name\n";
                return;
            }

            my $item = $iter->next();    # This is the one they'll buy
            unless ($item) {
                $self->error_message("Item $slot_name is empty");
                next;
            }
            
            push @bought_items, $item->dispense;
        }
        
        my @change;
        if (@bought_items) {
            @change = $self->_complete_purchase_and_make_change_for_selections(@bought_items);
        }

        return (@change,@bought_items);
    };

    if ($@) {
        my($error) = ($@ =~ m/^(.*?)\n/);
        $self->error_message("Couldn't process your purchase:\n$error");
        $transaction->rollback();
        return;
    } else {
        $transaction->commit();
        return @returned_items;
    }
}


# Note that this will die if there's a problem making change 
sub _complete_purchase_and_make_change_for_selections {
    my($self,@bought_items) = @_;

    my $coin_box = $self->coin_box_slot();

    my $purchased_value = 0;
    foreach my $item ( @bought_items ) {
        $purchased_value += $item->cost_cents;
    }
    my $change_value = $coin_box->content_value() - $purchased_value;

    if ($change_value < 0) {
        die "You did not enter enough money\n";
    }

    # Put all the user's coins into the bank
    my $bank_slot = $self->bank_slot;
    $coin_box->transfer_items_to_slot($bank_slot);

    if ($change_value == 0) {
        return;
    }

    # List of coin types in decreasing value
    my @available_coin_types = map { $_->name }
                               sort { $b->value_cents <=> $a->value_cents }
                               Vending::CoinType->get();

    my $change_dispenser = $self->change_slot;
    my @change;
    # Make change for the user
    MAKING_CHANGE:
    foreach my $coin_name ( @available_coin_types ) {
        my $coin_iter = $change_dispenser->coin_item_iterator(name => $coin_name);
        unless ($coin_iter) {
            die "Can't create iterator for Vending::Coin::Change\n";
        }
           
        THIS_coin_type:
        while ( my $coin = $coin_iter->next() ) {
            last if $change_value < $coin->value_cents;

            my($change_coin) = $coin->dispense;
            $change_value -= $change_coin->value;
            push @change, $change_coin;
        }
    }

    if ($change_value) {
        $DB::single=1;
        die "Not enough change\n";
    }

    return @change;
}

# Called by the test cases to empty out the machine
sub _initialize_for_tests {
    my $self = shift;

    $_->delete foreach Vending::Content->get();
    $_->delete foreach Vending::Product->get();
    
    $self->slots(name => 'a')->cost_cents(65);
    $self->slots(name => 'b')->cost_cents(100);
    $self->slots(name => 'c')->cost_cents(150);
}



1;
  
