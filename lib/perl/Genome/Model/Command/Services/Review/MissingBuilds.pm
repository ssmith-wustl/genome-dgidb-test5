package Genome::Model::Command::Services::Review::MissingBuilds;

class Genome::Model::Command::Services::Review::MissingBuilds {
    is => 'Genome::Command::Base',
    doc => 'Identify models that are missing builds.',
    has => [
        request_build => {
            is => 'Boolean',
            default => 0,
        },
    ],
};

use strict;
use warnings;
use Genome;

sub execute {
    my $self = shift;

    my @m = Genome::Model->get(
        _last_complete_build_id => '',
        'build_requested !=' => '1',
        user_name => ['apipe-builder', 'ebelter'],
    );
    print STDERR "Found " . @m . " models.\n";

    my @m_need_build;
    for my $m (@m) {
        next if ($m->latest_build);
        next if ($m->build_requested && $m->build_requested =~ /^1$/);
        push @m_need_build, $m;
    }

    print STDERR "Found " . @m_need_build . " models that need a build.\n";

    for my $m (@m_need_build) {
        if ($self->request_build) {
            $m->build_requested(1);
        }
        else {
            print $m->id . "\t" . $m->processing_profile->name . "\n";
        }
    }

    if ($self->request_build) {
        print "Requested builds for " . @m_need_build . " models.\n";
    }
}
