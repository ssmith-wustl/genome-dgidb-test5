package Genome::Model::Tools::TechD::CoverageStatsSummary;

use strict;
use warnings;

use Genome;


class Genome::Model::Tools::TechD::CoverageStatsSummary{
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
    my $stats_summary = $build->coverage_stats_summary_hash_ref;
    print Data::Dumper::Dumper($stats_summary);
    return 1;
}
