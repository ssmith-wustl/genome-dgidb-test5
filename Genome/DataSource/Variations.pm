package Genome::DataSource::Variations;

use Genome;

class Genome::DataSource::Variations{
    is => ['UR::DataSource::FileMux', 'UR::Singleton'],
};

sub delimiter {
    return "\t";
}

sub column_order {
return [qw( variation_id allele_string variation_type chrom_name start stop submitter_name database version )];
}

sub sort_order {
    return ['start'];
}

sub skip_first_line {
    return 0;
}

sub constant_values { ['data_directory'] };
sub required_for_get { [qw( chrom_name data_directory)] }

sub file_resolver {

    my($chrom_name, $data_directory) = @_;

    my $path = "$data_directory/variations_" . $chrom_name . ".csv";
    return $path;
}

1;

