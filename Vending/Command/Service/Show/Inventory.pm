package Vending::Command::Service::Show::Inventory;

use strict;
use warnings;
use Vending;

class Vending::Command::Service::Show::Inventory {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name => { value => 'Vending::Inventory' },
        show => { value => 'id,slot_name,name,insert_date' },
        filter => { is_calculated => 1 },
    ],
};

sub filter {
    my $self = shift;
    my $slot_names = $self->bare_args;

$DB::single=1;
    my $filter;
    if (@$slot_names == 0) {
        $filter = '';
    } elsif (@$slot_names == 1) {
        $filter = 'slot_name='.$slot_names->[0];
    } else {
        $filter = 'slot_name=:'.join('/',@$slot_names);
    }
    return $filter;
}



1;


