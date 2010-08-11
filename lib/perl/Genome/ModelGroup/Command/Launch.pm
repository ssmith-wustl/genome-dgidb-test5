package Genome::ModelGroup::Command::Launch;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Launch {
    is => ['Command'],
    has_optional => [
    model_group_id => { is => 'Integer', doc => 'id of the model-group to check'},
    model_group_name => { is => 'String', doc => 'name of model-group'},
    max => { is => 'Integer', doc => 'how many models should be scheduled', default => 1},
    ],
    doc => "launches builds for any models in model group that do not have a build",
};

sub execute {
    my $self = shift;
    my %status;
    my $mg;
    if($self->model_group_id && $self->model_group_name) {
        $self->error_message("Please specify either ID or name, not both.");
        die $self->error_message;
    }
    elsif($self->model_group_id) {
        $mg = Genome::ModelGroup->get($self->model_group_id);
    }
    elsif($self->model_group_name) {
        $mg = Genome::ModelGroup->get(name => $self->model_group_name);
    }
    else {
        $self->error_message("Please specify either an ID xor a name.");
        die $self->error_message;
    }

    my $running_count = 0;
    my @inactive_models;
    my @models = $mg->models;
    for my $m (@models) {
        my @build_ids = $m->build_ids;
        if (@build_ids) {
            my ($b_id) = sort {$b <=> $a} @build_ids;
            my $build = Genome::Model::Build->get($b_id);
            my $status = $build->status;
            $running_count++ if($status eq 'Running' || $status eq 'Scheduled');
        }
        else {
            push @inactive_models, $m;
        }

    }

    for my $m (@inactive_models) {
        if (($running_count  + 1 ) <= $self->max) {
            print "Starting " . $m->name . "...\n";
            system("genome model build start --model-identifier=" . $m->id);
            $running_count++;
        }
        else {
            print "Cannot start more models (running: $running_count, max: " . $self->max . ").\n";
            last;
        }
    }
}
1;
