package Vending::Product;

use strict;
use warnings;

use Vending;
class Vending::Product {
    type_name => 'product',
    table_name => 'PRODUCT',
    is => ['Vending::ItemType'],
    id_by => [
        product_id => { is => 'integer' },
    ],
    has => [
        manufacturer      => { is => 'varchar' },
        cost_cents        => { is => 'integer' },
        price             => { calculate_from => 'cost_cents',
                               calculate => 'sprintf("\$%.2f", $cost_cents/100)',
                               doc => 'display price in dollars' },
    ],
    id_sequence_generator_name => 'URMETA_ITEM_TYPE_TYPE_ID_seq',
    doc => 'kinds of things the machine sells',
    schema_name => 'Machine',
    data_source => 'Vending::DataSource::Machine',
};

1;
