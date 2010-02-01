
# review gsanders jlolofie
# note: maybe calculate usage estmate instead of hardcoded value

package Genome::Model::Build::Somatic;
#:adukes this looks fine, there may be some updates required for changes to model inputs and new build protocol, ebelter will be a better judge

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Somatic {
    is => 'Genome::Model::Build',
    has_optional => [
        tumor_build_links                  => { is => 'Genome::Model::Build::Link', reverse_as => 'to_build', where => [ role => 'tumor'], is_many => 1,
                                               doc => 'The bridge table entry for the links to tumor builds (should only be one)' },
        tumor_build                     => { is => 'Genome::Model::Build', via => 'tumor_build_links', to => 'from_build', 
                                               doc => 'The tumor build with which this build is associated' },
        normal_build_links                  => { is => 'Genome::Model::Build::Link', reverse_as => 'to_build', where => [ role => 'normal'], is_many => 1,
                                               doc => 'The bridge table entry for the links to normal builds (should only be one)' },
        normal_build                     => { is => 'Genome::Model::Build', via => 'normal_build_links', to => 'from_build', 
                                               doc => 'The tumor build with which this build is associated' },
    ],
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    $DB::single=1;
    unless ($self) {
        return;
    }
    my $model = $self->model;
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        return;
    }

    my $tumor_model = $model->tumor_model;
    unless ($tumor_model) {
        $self->error_message("Failed to get a tumor_model!");
        return;
    }
    
    my $normal_model = $model->normal_model;
    unless ($normal_model) {
        $self->error_message("Failed to get a normal_model!");
        return;
    }
    
    my $tumor_build = $tumor_model->last_complete_build;
    unless ($tumor_build) {
        $self->error_message("Failed to get a tumor build!");
        return;
    }

    my $normal_build = $normal_model->last_complete_build;
    unless ($normal_build) {
        $self->error_message("Failed to get a normal build!");
        return;
    }

    $self->add_from_build(role => 'tumor', from_build => $tumor_build);
    $self->add_from_build(role => 'normal', from_build => $normal_build);
    
    return $self;
}

# Returns the newest somatic workflow instance associated with this build 
sub newest_somatic_workflow_instance {
    my $self = shift;

    my @sorted = sort {
        $b->id <=> $a->id
    } Workflow::Store::Db::Operation::Instance->get(
        name => 'Somatic Pipeline Build ' . $self->build_id
    );

    unless (@sorted) {
        $self->warning_message("No somatic workflow instances found for this build.");
        return;
    }
    
    return $sorted[0];
}

# Returns a hash ref with all of the inputs of the newest somatic workflow instance
sub somatic_workflow_inputs {
    my $self = shift;

    my $instance = $self->newest_somatic_workflow_instance;

    unless ($instance) {
        $self->error_message("no somatic workflow instance found (has build been started?)");
        die;
    }

    # returns hashref of workflow params like { input => value }
    return $instance->input;  
}

# Input: the name of the somatic workflow input you'd like to know
# Returns: value of one input of the latest somatic workflow instance.
sub somatic_workflow_input {
    my $self = shift;
    my $input_name = shift;

    my $input = $self->somatic_workflow_inputs;
    
    $DB::single=1;
    unless (exists $input->{$input_name}) {
        my @valid_inputs = sort(keys %$input);
        my $inputs_string = join(", ", @valid_inputs);
        $self->error_message("Input $input_name does not exist. Valid inputs to query for this build are: \n$inputs_string");
        die;
    }

    unless (defined $input->{$input_name}) {
        $self->error_message("Input $input_name exists, but is not defined for this build. Something may have gone wrong with the build.");
        die;
    }

    return $input->{$input_name};
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    # 1.5 gig... overestimating by 50% or so...
    return 1536000;
}

1;
