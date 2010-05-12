package Genome::Model::Tools::TechD::PicardDuplicationRatios;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::TechD::PicardDuplicationRatios{
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
    my $subject = $build->mark_duplicates_library_metrics_hash_ref;
    print Data::Dumper::Dumper($subject);
    return 1;
}

1;
