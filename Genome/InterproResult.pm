package Genome::InterproResult;

use strict;
use warnings;
use Genome;

class Genome::InterproResult {
    type_name => 'genome interpro result',
    id_by => [
        id => {
            is => 'Number',
        },
    ],
    has => [
        data_directory => {
            is => 'Path',
        },
        chrom_name => {
            is => 'Text',
        },
        start => {
            is => 'Number',
        },
        stop => {
            is => 'Number',
        },
        transcript_name => { 
            is => 'Text',
        },
        rid => {
            is => 'Number',
            is_optional => 1,
        },
        setid => {
            is => 'Text',
            is_optional => 1,
        },
        parid => {
            is => 'Text',
            is_optional => 1,
        },
        name => {
            is => 'Text',
            is_optional => 1,
        },
        inote => {
            is => 'Text',
            is_optional => 1,
        },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::InterproResults',
};

1;

