package Genome::Model::Build::Command::SetUnarchivable;

use strict;
use warnings;
use Genome;

class Genome::Model::Build::Command::SetUnarchivable {
    is => 'Command::V2',
    has => [
        builds => {
            is => 'Genome::Model::Build',
            is_many => 1,
            shell_args_position => 1,
            doc => 'builds that are to be marked as unarchivable',
        },
    ],
    has_optional => [
        reason => {
            is => 'Text',
            doc => 'reason for marking these builds are unarchivable',
        },
    ],
};

sub help_detail {
    return 'All allocations that are used by this build are marked as unarchivable. ' .
        'This includes allocations the build itself owns, all allocations that its ' .
        'inputs own, and allocations owned by software results this build uses.'
}
sub help_brief { return 'allocations used by provided builds are marked as unarchivable' };
sub help_synopsis { return help_brief() . "\n" };

sub execute {
    my $self = shift;
    for my $build ($self->builds) {
        for my $allocation ($build->all_allocations) {
            next unless $allocation->archivable;
            $allocation->archivable(0, $self->reason);
        }
    }
    $self->status_message("All builds marked as unarchivable");
    return 1;
}

1;

