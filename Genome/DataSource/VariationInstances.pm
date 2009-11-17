# Review gsanders: This can be removed and has not been used for some time

package Genome::DataSource::VariationInstances;

use Genome;

class Genome::DataSource::VariationInstances {
    is => ['UR::DataSource::FileMux', 'UR::Singleton'],
};

sub constant_values { ['build_id'] };
sub required_for_get { [qw( variation_id build_id)] }
sub delimiter { "\t" }
sub column_order {
    [ qw(
        variation_id
        submitter_id
        method_id
        date_stamp
    ) ]
}

sub sort_order { ['variation_id'] }

sub file_resolver {
    my($transcript_id, $build_id) = @_;
    
    my $file_id = int($transcript_id / 1000);
    my $dir_id = int($file_id/1000);
    $file_id .= '000';
    $dir_id .= '000000';
    
    my $build = Genome::Model::Build::ImportedAnnotation->get($build_id);
    my $annotation_dir = $build->annotation_data_directory;

    my $path = join('/',"$annotation_dir/variation_instance_tree",
                    $dir_id,
                    $file_id);
    $path .= '.csv';
    return $path;
}

1;
