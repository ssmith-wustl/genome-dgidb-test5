package Genome::Model::Tools::BioSamtools::CoverageStats;

use strict;
use warnings;

use Genome;
use Workflow::Simple;

my $DEFAULT_MINIMUM_DEPTHS = '1,5,10,15,20';
my $DEFAULT_WINGSPAN_VALUES = '0,200,500';

class Genome::Model::Tools::BioSamtools::CoverageStats {
    is => 'Genome::Model::Tools::BioSamtools',
    has_input => [
        bed_file => {
            is => 'Text',
            doc => 'A path to a BED format file of regions of interest',
        },
        bam_file => {
            is => 'Text',
            doc => 'A path to a BAM format file of aligned capture reads',
        },
        minimum_depths => {
            is => 'Text',
            doc => 'A comma separated list of minimum depths to evaluate coverage',
            default_value => $DEFAULT_MINIMUM_DEPTHS,
            is_optional => 1,
        },
        wingspan_values => {
            is => 'Text',
            doc => 'A comma separated list of wingspan values to add to each region of interest',
            default_value => $DEFAULT_WINGSPAN_VALUES,
            is_optional => 1,
        },
        minimum_base_quality => {
            is => 'Text',
            doc => 'A minimum base quality to consider in coverage assesment',
            default_value => 0,
            is_optional => 1,
        },
        minimum_mapping_quality => {
            is => 'Text',
            doc => 'A minimum mapping quality to consider in coverage assesment',
            default_value => 0,
            is_optional => 1,
        },
        output_directory => {
            is => 'Text',
            doc => 'The output directory to generate coverage stats',
        },
    ],
    has_output => [
        stats_files => { is => 'Array', is_many => 1, is_optional => 1, doc => 'a list of stats files produced by the workflow'},
        alignment_summaries => { is => 'Array', is_many => 1, is_optional => 1, doc => 'a list of alignment summaries produced by the workflow'},
        stats_summaries => { is => 'Array', is_many => 1, is_optional => 1, doc => 'a list of stats summaries produced by the workflow'},
    ]
};

sub execute {
    my $self = shift;
    unless (-d $self->output_directory) {
        unless (Genome::Utility::FileSystem->create_directory($self->output_directory)) {
            die('Failed to create output_directory: '. $self->output_directory);
        }
    }
    my $module_path = $self->get_class_object->module_path;
    my $xml_path = $module_path;
    $xml_path =~ s/\.pm/\.xml/;
    my @wingspans = split(',',$self->wingspan_values);
    my @minimum_depths = split(',',$self->minimum_depths);
    my $output = run_workflow_lsf($xml_path,
                                  bed_file => $self->bed_file,
                                  bam_file => $self->bam_file,
                                  wingspan => \@wingspans,
                                  minimum_depth => \@minimum_depths,
                                  output_directory => $self->output_directory,
                                  minimum_base_quality => $self->minimum_base_quality,
                                  minimum_mapping_quality => $self->minimum_mapping_quality,
                              );
    unless (defined $output) {
        for (@Workflow::Simple::ERROR) {
            print STDERR $_->error ."\n";
        }
    }
    my $alignment_summaries = $output->{alignment_summaries};
    unless (scalar(@$alignment_summaries) == scalar(@wingspans)) {
        die('Incorrect number of alignment summaries!');
    }
    $self->alignment_summaries($alignment_summaries);
    my $stats_file_array_ref = $output->{stats_files};
    my @stats_files;
    my $j = scalar(@$stats_file_array_ref);
    unless ($j == scalar(@wingspans)) {
        die('Incorrect number of wingspan iterations for stats files!');
    }
    for (my $i = 0; $i < $j; $i++) {
        my $stats_files = @$stats_file_array_ref[$i];
        unless (scalar(@$stats_files) == scalar(@minimum_depths)) {
            die('Incorrect number of stats files found per wingspan!');
        }
        push @stats_files, @$stats_files;
    }
    $self->stats_files(\@stats_files);
    my $stats_sum_array_ref = $output->{stats_summaries};
    my @stats_sums;
    my $k = scalar(@$stats_sum_array_ref);
    unless ($k == scalar(@wingspans)) {
        die('Incorrect number of wingspan iterations for stats summariess!');
    }
    for (my $i = 0; $i < $k; $i++) {
        my $stats_sums = @$stats_sum_array_ref[$i];
        unless (scalar(@$stats_sums) == scalar(@minimum_depths)) {
            die('Incorrect number of stats summaries found per wingspan!');
        }
        push @stats_sums, @$stats_sums;
    }
    $self->stats_summaries(\@stats_sums);
    return 1;
}

1;
