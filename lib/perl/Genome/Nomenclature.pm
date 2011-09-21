package Genome::Nomenclature;

use strict;
use warnings;

use Command::Dispatch::Shell;
use Genome;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use JSON::XS;

class Genome::Nomenclature {
    table_name => 'GENOME_NOMENCLATURE',
    id_generator => '-uuid',
    id_by => {
        'id' => {is=>'Text', len=>64}
    },
    has => [
        name => {
            is=>'Text', 
            len=>255, 
            doc => 'Nomenclature name'
        },
        fields => {
            is => 'Genome::Nomenclature::Field',
            is_many => 1,
            reverse_as => 'nomenclature'
        }
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Nomenclatures'
};


1;
