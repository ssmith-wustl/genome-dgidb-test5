package Genome::ModelGroup::Command::Member::Add;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Member::Add {
    is => 'Genome::ModelGroup::Command::Member',
    has => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            shell_args_position => 2,
            doc => 'Model(s) to add to the group. Resolved from command line via text string.',
        },
    ],
    doc => 'add member models to a model-group',
};

sub help_brief {
    return "Add models to a group";
}

sub help_synopsis {
    return <<HELP;
    genome model-group member add \$MODEL_GROUP \$MODELS

    Add model id 2813411994 to group id 21 =>
     genome model-group member add 21 2813411994
    
    Add model ids 2813411994 and 2813326667 to group named 'Models by Charris' =>
     genome model-group member add 'Models by Charris' 2813411994,2813326667

    Add models named starting w/ Charris to group named 'Models by Charris' =>
     genome model-group member add 'Models by Charris' 'Charris%'
HELP
}

sub help_detail {                           
    return;
}

sub execute {
    my $self = shift;
    
    my $model_group = $self->model_group
        or return;

    my @models = $self->models
        or return;

    $model_group->assign_models(@models);

    $self->status_message('Added '.scalar(@models).' to group '.$model_group->__display_name__);
    
    return 1; #Things might not have gone perfectly, but nothing crazy happened
}

sub _limit_results_for_models {
    my ($class, @models) = @_;

    my %existing_models = map { $_->id => $_ } $class->model_group->models;

    return if not %existing_models;
    
    my @models_to_add;
    for my $model ( @models ) {
        if ( exists $existing_models{ $model->id } ) {
            next;
        }
        push @models_to_add, $model;
    }

    if ( @models_to_add != @models ) {
        my $already_existing = @models - @models_to_add;
        $class->warning_message("Skipping $already_existing of the ".scalar(@models)." models given because thay are already members.");
    }

    return @models_to_add;
}

1;

