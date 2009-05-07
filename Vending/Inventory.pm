package Vending::Inventory;

use strict;
use warnings;

use Vending;
class Vending::Inventory {
    is => [ 'Vending::Content' ],
    type_name => 'inventory',
    table_name => 'inventory',
    id_by => [
        inv_id => { is => 'integer' },
    ],
    has => [
        #type_name    => { default_value => 'Vending::Inventory', is_constant => 1, is_transient => 1 },
        product      => { is => 'Vending::Product', id_by => 'product_id', constraint_name => 'inventory_product_ID_product_product_ID_FK' },

        insert_date  => { is => 'datetime' },
        product_id   => { is => 'integer', implied_by => 'product' },
        name         => { via => 'product' },
        cost_cents   => { via => 'product' },
        price        => { via => 'product' },
        manufacturer => { via => 'product' },
    ],
    id_sequence_generator_name => 'URMETA_coin_coin_ID_seq',
    schema_name => 'Machine',
    data_source => 'Vending::DataSource::Machine',
    doc => 'instances of things the machine will sell and dispense',
};

sub type_name_resolver {
    return __PACKAGE__;
}

1;
