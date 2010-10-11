package Genome::Model::Build::Command::Base;

class Genome::Model::Build::Command::Base {
    is          => 'Genome::Command::Base',
    is_abstract => 1,
    has         => [
        builds => {
            is                  => 'Genome::Model::Build',
            require_user_verify => 1,
            is_many             => 1,
            shell_args_position => 1,
            doc =>
              'Build(s) to use. Resolved from command line via text string.',
        },
    ],
};

sub _limit_results_for_builds {
    my ( $class, @builds ) = @_;

    $class->status_message("Filtering matching builds for builds you ran.");
    my $other_users_builds_count;
    my @run_by_builds;
    for my $build (@builds) {
        if ( $build->run_by && $build->run_by ne $ENV{USER} ) {
            $other_users_builds_count++;
        }
        else {
            push @run_by_builds, $build;
        }
    }
    if ($other_users_builds_count) {
        $class->warning_message(
            "Filtered $other_users_builds_count builds not run by you.");
    }
    else {
        $class->status_message("No builds filtered.");
    }
    @builds = @run_by_builds;

    return @builds;
}

1;

