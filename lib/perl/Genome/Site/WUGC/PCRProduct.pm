package Genome::Site::WUGC::PCRProduct;
use strict;
use warnings;
use Genome;

class Genome::Site::WUGC::PCRProduct { 
    table_name => 'GSC.PCR_PRODUCT@oltp pcr_product',
    id_by => 'pcr_id',
    has => [
        'name' => { column_name => 'pcr_name' }, 
    ],
    data_source => 'Genome::DataSource::GMSchema'
};


1;

