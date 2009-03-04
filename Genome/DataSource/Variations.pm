package Genome::DataSource::Variations;

use Genome;

class Genome::DataSource::Variations{
    is => 'UR::DataSource::FileMux',
};

sub delimiter {
    return "\t";
}

sub column_order {

return
qw(
variation_id
external_variation_id
allele_string
variation_type
chrom_name
start
stop
pubmed_id
);
}

sub sort_order {
    return qw( start );
}

sub skip_first_line {
    return 0;
}

sub required_for_get { qw( chrom_name ) }

sub file_resolver {
    my($chrom_name) = @_;

    $DB::single =1;
    
    my $path = '/gscmnt/sata363/info/medseq/annotation_data/variations/variations_' . $chrom_name . ".csv";
    return $path;
}

1;

