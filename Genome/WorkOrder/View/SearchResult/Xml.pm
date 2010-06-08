package Genome::WorkOrder::View::SearchResult::Xml;

use strict;
use warnings;

use Genome;

class Genome::WorkOrder::View::SearchResult::Xml {
    is => 'Genome::View::SearchResult::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            default => [
                'id',
                'barcode',
                'pipeline',
                'project_name',
                'setup_name',
                'setup_description',
                {
                    name => 'project',
                    aspects => ['id', 'name'],
                    perspective => 'default',
                    toolkit => 'xml'
                },
            ]
        }
    ]
};


# GSC::Setup::WorkOrder
#    my $name_string =$self->id . "-" .$name ."-" . $dna_count .$type .  "-" .$self->get_creation_event->quick_report_date;
#


1;
