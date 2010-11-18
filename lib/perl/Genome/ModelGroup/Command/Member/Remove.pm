package Genome::ModelGroup::Command::Member::Remove;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Member::Remove {
    is => 'Genome::ModelGroup::Command::Member',
    has => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            shell_args_position => 2,
            require_user_verify => 1,
            doc => 'Model(s) to remove from the group. Resolved from command line via text string.',
        },
    ],
    doc => 'remove member models from a model-group',
};

sub help_brief {
    return "remove models from a model-group";
}

sub help_synopsis {                           
    return <<"EOS"
    genome model-group member remove \$MODEL_GROUP \$MODELS

    Remove model id 2813411994 from group id 21 =>
     genome model-group member remove 21 2813411994
    
    Remove model ids 2813411994 and 2813326667 from group named 'Models by Ndees' =>
     genome model-group member remove 'Models by Ndees' 2813411994,2813326667

    Remove models named starting w/ Ndees from group named 'Models by Ndees' =>
     genome model-group member remove 'Models by Ndees' 'Ndees%'
EOS
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

    $model_group->unassign_models(@models);

    $self->status_message('Removed '.scalar(@models).' from group '.$model_group->__display_name__);

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

