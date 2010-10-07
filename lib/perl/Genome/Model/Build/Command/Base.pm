package Genoem::Model::Build::Command::Base;

class Genome::Model::Build::Command::Base {
    is => 'Genome::Command::Base',
    has => [
        builds => {
            is => 'Genome::Model::Build',
            require_user_verify => 1,
            is_many => 1,
            shell_args_position => 1,
            doc => 'Build(s) to use. Resolved from command line via text string.',
        },
    ],
};

sub _limit_results_for_builds {
    my ($self, @builds) = @_;

    my $other_users_builds_count;
    my @run_by_builds;
    for my $build (@builds) {
        if ($build->run_by eq $ENV{USER}) {
            push @run_by_builds, $build;
        }
        else {
            $other_users_builds_count++;
        }
    }
    if ($other_users_builds_count) {
        $self->warning_message("Filtered $other_users_builds_count builds not run by you.");
    }
    @builds = @run_by_builds;

    return @builds;
}

1;

