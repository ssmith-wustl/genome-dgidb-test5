package Vending::CoinType;

use strict;
use warnings;

use Vending;
class Vending::CoinType {
    type_name => 'coin type',
    table_name => 'COIN_TYPE',
    id_by => [
        name => { is => 'String' },
    ],
    has => [
        value_cents => { is => 'integer' },
        item_type   => { is => 'Vending;:ItemType', where => [ name => \'name'] },
        type_id     => { via => 'item_type' },
    ],
    doc => 'kinds of coins the machine accepts, and their value',
    data_source => 'Vending::DataSource::CoinType',
};

# Overriding because the property definition doesn't exactly work...
sub item_type {
    my $self = shift;
    my $type_obj = Vending::ItemType->get_or_create(name => $self->name);
    return $type_obj;
}

1;
