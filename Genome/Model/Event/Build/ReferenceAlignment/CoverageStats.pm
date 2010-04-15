package Genome::Model::Event::Build::ReferenceAlignment::CoverageStats;

use strict;
use warnings;

use File::Path qw(rmtree);

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::CoverageStats {
    is => ['Genome::Model::Event'],
    has => [ ],
};

sub execute {
    my $self = shift;

    my $coverage_dir = $self->build->reference_coverage_directory;
    if (-d $coverage_dir) {
        #just remove the existing one to avoid shortcutting without verification...
        #TODO: Add verification and the ability to shortcut if output exists and is complete
        unless (rmtree($coverage_dir)) {
            $self->error_message('Failed to remove existing coverage directory '. $coverage_dir);
            die($self->error_message);
        }
    }
    unless (Genome::Utility::FileSystem->create_directory($coverage_dir)) {
        $self->error_message('Failed to create coverage directory '. $coverage_dir .":  $!");
        return;
    }
    my $bed_file = $self->build->capture_set_bed_file;
    my %coverage_stats_params = (
        output_directory => $coverage_dir,
        bed_file => $self->build->capture_set_bed_file,
        bam_file => $self->build->whole_rmdup_bam_file,
    );

    my $coverage_stats_params = $self->model->coverage_stats_params;
    if (defined($coverage_stats_params)) {
        my ($minimum_depths,$wingspan_values,$quality_filter) = split(':',$coverage_stats_params);
        if ($minimum_depths && $wingspan_values) {
            $coverage_stats_params{minimum_depths} = $minimum_depths;
            $coverage_stats_params{wingspan_values} = $wingspan_values;
            if (defined($quality_filter)) {
                $coverage_stats_params{minimum_base_quality} = $quality_filter;
            }
        } else {
            die('Failed to parse coverage_stats_params: '. $coverage_stats_params);
        }
    }
    unless (Genome::Model::Tools::BioSamtools::CoverageStats->execute(%coverage_stats_params)) {
        $self->error_message('Failed to generate coverage stats with params: '.  Data::Dumper::Dumper(%coverage_stats_params));
        die($self->error_message);
    }
    return 1;
}

1;
