package Genome::Model::Command::SetUnarchivable;

use strict;
use warnings;
use Genome;

class Genome::Model::Command::SetUnarchivable {
    is => 'Command::V2',
    has => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            shell_args_position => 1,
            doc => 'models to have their latest complete build marked as unarchivable',
        },
    ],
    has_optional => [
        reason => {
            is => 'Text',
            doc => 'reason provided models are to be set as unarchivable',
        },
    ],
};

sub help_detail {
    return 'The last complete build for each model is marked as unarchivable. This process ' .
        'marks all allocations those builds use as unarchivable, including instrument data, ' .
        'alignment results, variation detection results, and other inputs';
}
sub help_brief { return 'marks last complete build of each model as unarchivable' };
sub help_synopsis { return help_brief() . "\n" };

sub execute {
    my $self = shift;
    for my $build (map { $_->last_complete_build } $self->models) {
        for my $allocation ($build->all_allocations) {
            next unless $allocation->archivable;
            $allocation->archivable(0, $self->reason);
        }
    }
    $self->status_message("Last complete build of provided models marked as unarchivable");
    return 1;
}

1;

