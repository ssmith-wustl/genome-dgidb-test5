package Genome::Site::WUGC::Ligation;
use strict;
use warnings;
use Genome;

class Genome::Site::WUGC::Ligation { 
    table_name => 'GSC.LIGATIONS@oltp ligation',
    id_by => 'lig_id',
    has => [
        'name' => { column_name => 'ligation_name' }, 
    ],
    data_source => 'Genome::DataSource::GMSchema'
};


1;

