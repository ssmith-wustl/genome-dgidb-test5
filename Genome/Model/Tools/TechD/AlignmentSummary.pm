package Genome::Model::Tools::TechD::AlignmentSummary;

use strict;
use warnings;

use Genome;


class Genome::Model::Tools::TechD::AlignmentSummary {
    is => ['Command'],
    has => {
        build_id => { },
    },
};

sub execute {
    my $self = shift;
    my $build = Genome::Model::Build->get($self->build_id);
    unless ($build) {
        die('Failed to find build by id '. $self->build_id);
    }
    my $alignment_summary = $build->alignment_summary_hash_ref;
    print Data::Dumper::Dumper($alignment_summary);
    return 1;
}
