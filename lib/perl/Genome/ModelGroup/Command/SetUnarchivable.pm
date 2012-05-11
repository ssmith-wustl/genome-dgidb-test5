package Genome::ModelGroup::Command::SetUnarchivable;

use strict;
use warnings;
use Genome;

class Genome::ModelGroup::Command::SetUnarchivable {
    is => 'Command::V2',
    has => [
        model_groups => {
            is => 'Genome::ModelGroup',
            is_many => 1,
            shell_args_position => 1,
            doc => 'model groups whose members\' last complete build are to be marked as unarchivable',
        },
    ],
    has_optional => [
        reason => {
            is => 'Text',
            doc => 'reason for setting these model groups as unarchivable',
        },
    ],
};

sub help_detail {
    return 'The last complete build of each model in the provided model groups is marked as ' .
        'unarchivable. That process marks all inputs to the build and all software results as ' .
        'unarchivable, preventing them from ever being archived';
}
sub help_brief { return 'last complete build of each model in the provided group(s) marked as unarchivable' };
sub help_synopsis { return help_brief() . "\n" };

sub execute {
    my $self = shift;
    for my $group ($self->model_groups) {
        for my $build (map { $_->last_complete_build } $group->models) {
            for my $allocation ($build->all_allocations) {
                next unless $allocation->archivable;
                $allocation->archivable(0, $self->reason);
            }
        }
    }
    $self->status_message("All last complete builds of models in provided groups marked as unarchivable");
    return 1;
}

1;

