package Genome::Model::Tools::TechD::BuildAlignmentSummary;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::TechD::BuildAlignmentSummary {
    is => ['Command'],
    has => {
        build_id => { },
        build => {
            is => 'Genome::Model::Build',
            id_by => 'build_id',
        }
    }
};

sub execute {
    my $self = shift;
    my $build = $self->build;
    unless ($build) {
        die('No build found for build_id '. $self->build_id);
    }
    my ($deduplicate_event) = grep { $_->event_type =~ /^genome model build reference-alignment deduplicate-libraries/ } $build->the_events;
    unless ($deduplicate_event->event_status eq 'Succeeded') {
        die('The deduplicate event is not Succeeded for build '. $build->id);
    }
    my $bam_file = $build->whole_rmdup_bam_file;
    unless (Genome::Model::Tools::BioSamtools::AlignmentSummaryCpp->execute(
        bam_file => $bam_file,
        output_directory => $build->accumulated_alignments_directory,
    )) {
        die('Failed to run algnment summary on bam file '. $bam_file);
    }
    return 1;
}

1;
