package Genome::DataSource::Submitters;

use strict;
use warnings;
use Genome;

class Genome::DataSource::Submitters{
    is => 'UR::DataSource::File',
};

sub delimiter {
    return "\t";
}

sub column_order{
    return qw( 
    submitter_id 
    submitter_name 
    variation_source 
    )
}

sub sort_order{
    return qw( 
    submitter_id 
    )
}

sub skip_first_line {
    return 0;
}

sub file_list {
    return qw( 
    /gscmnt/sata363/info/medseq/annotation_data/submitters.csv 
    )
}

1;

