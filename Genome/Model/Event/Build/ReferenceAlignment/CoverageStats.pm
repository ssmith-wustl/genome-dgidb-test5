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
    my $bed_file = $self->build->region_of_interest_set_bed_file;
    my %coverage_stats_params = (
        output_directory => $coverage_dir,
        bed_file => $bed_file,
        bam_file => $self->build->whole_rmdup_bam_file,
        minimum_depths => $self->build->minimum_depths,
        wingspan_values => $self->build->wingspan_values,
    );

    my $minimum_base_quality = $self->build->minimum_base_quality;
    if (defined($minimum_base_quality)) {
        $coverage_stats_params{minimum_base_quality} = $minimum_base_quality;
    }
    my $minimum_mapping_quality = $self->build->minimum_mapping_quality;
    if (defined($minimum_mapping_quality)) {
        $coverage_stats_params{minimum_mapping_quality} = $minimum_mapping_quality;
    }
    unless (Genome::Model::Tools::BioSamtools::CoverageStats->execute(%coverage_stats_params)) {
        $self->error_message('Failed to generate coverage stats with params: '.  Data::Dumper::Dumper(%coverage_stats_params));
        die($self->error_message);
    }
    return 1;
}

1;
