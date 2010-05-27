package Genome::Model::Tools::TechD::SummarizeCaptureBuilds;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::TechD::SummarizeCaptureBuilds {
    is => ['Command'],
    has => [
        build_ids => { is => 'Text', doc => 'a comma delimited list of build ids to compare' },
        alignment_summary => { is => 'Text', doc => 'The output tsv file of consolidated alignment summaries' },
        coverage_summary => { is => 'Text', doc => 'The output tsv file of consolidated coverage metrics' },
        wingspan => { is_optional => 1, default_value => 0 },
    ],
};

sub execute {
    my $self = shift;

    my @build_ids = split(',',$self->build_ids);
    unless (Genome::Model::Tools::TechD::ConvergeAlignmentSummaries->execute(
        build_ids => \@build_ids,
        output_file => $self->alignment_summary,
        wingspan => $self->wingspan,
    )) {
        die('Failed to generate alignment summary '. $self->alignment_summary ." for builds:\n\t". join("\n\t", @build_ids));
    }
    unless (Genome::Model::Tools::TechD::ConvergeCoverageStatsSummaries->execute(
        build_ids => \@build_ids,
        output_file => $self->coverage_summary,
        wingspan => $self->wingspan,
    )) {
        die('Failed to generate coverage summary '. $self->coverage_summary ." for builds:\n\t". join("\n\t", @build_ids));
    }
    return 1;
}


1;
