package Vending::Coin;

use strict;
use warnings;

use Vending;
class Vending::Coin {
    type_name => 'coin',
    table_name => 'coin',
    is => 'Vending::Content',
    id_by => [
        coin_id => { is => 'integer' },
    ],
    has => [
        #type_name    => { is_constant => 1, value => 'Vending::Coin', is_transient => 1 },
        item_type    => { is => 'Vending::ContentType', id_by => 'type_id' },

        name         => { via => 'item_type', to => 'name' },
        coin_type    => { is => 'Vending::CoinType', id_by => 'name' },
        value_cents  => { via => 'coin_type', to => 'value_cents' },
    ],
    id_sequence_generator_name => 'URMETA_coin_coin_ID_seq',
    schema_name => 'Machine',
    data_source => 'Vending::DataSource::Machine',

    doc => 'instances of coins being handled by the machine',
};

sub type_name_resolver {
    return __PACKAGE__;
}


1;
