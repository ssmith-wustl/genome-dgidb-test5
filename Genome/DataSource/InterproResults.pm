package Genome::DataSource::InterproResults;

use strict;
use warnings;
use Genome;

class Genome::DataSource::InterproResults {
    is => [ 'UR::DataSource::FileMux', 'UR::Singleton' ],
};

sub delimiter { "," }

sub column_order {
   [ 'id', 'start', 'stop', 'transcript_name', 'rid', 'setid', 'parid', 'name', 'inote' ];
}

sub required_for_get { 
    [ 'data_directory', 'chrom_name' ]; 
}

sub file_resolver {
    my ($data_directory, $chrom_name) = @_;
    my $path = $data_directory . "/interpro_results/chromosome_" . $chrom_name . ".csv";
    return $path;
}

1;

