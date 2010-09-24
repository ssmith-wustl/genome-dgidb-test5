package Genome::ModelGroup::Command::Builds::Status;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Builds::Status {
    is => ['Genome::ModelGroup::Command::Builds'],
    doc => "check status of last build for each model in model group",
};

sub execute {
    my $self = shift;
    my %status;
    my $mg = $self->get_mg;
    my @models = $mg->models;
    for my $m (@models) {
        my $b_id = $m->latest_build;
        if ($b_id) {
            my $build = Genome::Model::Build->get($b_id);
            $status{$build->status}++;
        }
        else {
            $status{Other}++;
        }
    }
    print "Model Group: " . $mg->name . "\n";
    for my $key (sort(keys(%status))) {
        print "$key: $status{$key}\t";
    }
    print "Total: " . scalar(@models) . "\n";

    return 1;
}

1;
