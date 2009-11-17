# Review gsanders: This can be removed and has not been used for some time

package Genome::DataSource::Submitters;

use strict;
use warnings;
use Genome;

class Genome::DataSource::Submitters{
    is => ['UR::DataSource::FileMux', 'UR::Singleton'],
};

sub delimiter {
    return "\t";
}

sub column_order{
    return [qw( 
    submitter_id 
    submitter_name 
    variation_source 
    )];
}

sub sort_order{
    return ['submitter_id'];
}

sub skip_first_line {
    return 0;
}

sub constant_values { ['build_id'] };
sub required_for_get { ['build_id'] }

sub file_resolver {
    my ($build_id) = @_;
    my $build = Genome::Model::Build::ImportedAnnotation->get($build_id);
    my $annotation_dir = $build->annotation_data_directory;
    my $path = "$annotation_dir/submitters.csv";
    return $path;
}

1;

