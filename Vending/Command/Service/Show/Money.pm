package Vending::Command::Service::Show::Money;

class Vending::Command::Service::Show::Money {
    is_abstract => 1,
    is => 'Command',
    doc => 'parent class for show change and show bank',
    has => [
        slot_name => { is => 'String', is_abstract => 1 },
    ],
};

sub execute {
    my $self = shift;

    my $slot = Vending::VendSlot->get(name => $self->slot_name);
    unless ($slot) {
        $self->error_message("There is no slot named ".$self->slot_name);
        return;
    }

    my @coins = $slot->items;

    my %coins_by_type;
    my $total_value = 0;

    foreach my $coin ( @coins ) {
        $coins_by_type{$coin->name}++;
        $total_value += $coin->value_cents;
    }

    while(my($type,$count) = each %coins_by_type) {
        printf("%-7s:%6d\n", $type,$count);
    }
    printf("Total:\t\$%.2f\n",$total_value/100);
    return 1;

}
1;

