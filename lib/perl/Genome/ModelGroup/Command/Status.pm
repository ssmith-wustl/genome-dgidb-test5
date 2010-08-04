package Genome::ModelGroup::Command::Status;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Status {
    is => ['Command'],
    has_optional => [
        model_group_id => { is => 'Integer', doc => 'id of the model-group to check'},
        model_group_name => { is => 'String', doc => 'name of model-group'},
    ],
    doc => "check status of last build for each model in model group",
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
    my @models = $mg->models;
    for my $m (@models) {
        my @build_ids = $m->build_ids;
        if (@build_ids) {
            my ($b_id) = sort {$b <=> $a} @build_ids;
            my $build = Genome::Model::Build->get($b_id);
            $status{$build->status}++;
        }
        else {
            $status{Other}++;
        }
    }
    print "Model Group: " . $mg->name . "\t";
    for my $key (sort(keys(%status))) {
        print "$key: $status{$key}\t";
    }
    print "Total: " . scalar(@models) . "\n";

}

1;
