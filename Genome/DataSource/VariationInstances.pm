package Genome::DataSource::VariationInstances;

use Genome;

class Genome::DataSource::VariationInstances {
    is => 'UR::DataSource::FileMux',
};

sub constant_values { qw() };
sub required_for_get { qw( variation_id ) }
sub delimiter { "\t" }
sub column_order {
    qw(
        variation_id
        submitter_id
        method_id
        date_stamp
    )
}

sub sort_order { qw( variation_id ) }

sub file_resolver {
    my($transcript_id) = @_;
    
    my $file_id = int($transcript_id / 1000);
    my $dir_id = int($file_id/1000);
    $file_id .= '000';
    $dir_id .= '000000';
    my $path = join('/','/gscmnt/sata363/info/medseq/annotation_data/variation_instance_tree',
                    $dir_id,
                    $file_id);
    $path .= '.csv';
    return $path;
}

1;
