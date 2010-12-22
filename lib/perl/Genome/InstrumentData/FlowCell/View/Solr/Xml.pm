package Genome::InstrumentData::FlowCell::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::FlowCell::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'illumina_run'
        },
        default_aspects => {
            is => 'ARRAY,',
            default => [
                {
                    name => 'flow_cell_id',
                    position => 'title',
                },
                {
                    name => 'instrument_data_ids',
                    position => 'content',
                },
                {
                    name => 'flow_cell_id',
                    position => 'content',
                },
                {
                    name => 'machine_name',
                    position => 'content',
                },
                {
                    name => 'run_name',
                    position => 'content',
                },
                {
                    name => 'run_type',
                    position => 'content',
                }
            ]
        },
    ]
};

1;
