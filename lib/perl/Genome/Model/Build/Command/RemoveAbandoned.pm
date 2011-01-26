package Genome::Model::Build::Command::RemoveAbandoned;

use strict;
use warnings;
use Genome;
use Carp;

class Genome::Model::Build::Command::RemoveAbandoned {
    is => 'Command',
    doc => 'Removes all abandoned build owned by the user',
    has_optional => [
        keep_build_directory => {
            is => 'Boolean',
            default_value => 0,
            doc => 'If set, builds directories for all removed builds will be kept',
        },
    ],
};

sub help_brief {
    return 'Remove all abandoned builds owned by the user';
}

sub help_detail {
    return <<EOS
This command will grab all builds owned by the user and remove them all
EOS
}

sub execute {
    my $self = shift;

    my $user = $ENV{USER};
    confess "Could not get user name from environment" unless defined $user;

    my @builds = map {$_->build} Genome::Model::Event->get(
        event_type => 'genome model build',
        event_status => 'Abandoned',
        user_name => $user,
        -hints => ["build"],
    );
    unless (@builds) {
        $self->status_message("No builds owned by $user are abandoned, so no removal necessary!");
        return 1;
    }

    $self->status_message("User $user has " . scalar @builds . " abandoned builds.");
    $self->status_message(join("\n", map { $_->__display_name__ } @builds));
    # TODO: use Genome::Command::Base->ask_user_question
    $self->status_message("Are you sure you want to remove these builds? (y/n) [n]");
    my $answer = <STDIN>;
    return unless $answer =~ /^[yY]/;

 
    my $remove_abandoned = Genome::Model::Build::Command::Remove->create(
        builds => \@builds,
        keep_build_directory => $self->keep_build_directory,
    );
    return $remove_abandoned->execute();
}

1;

