package Genome::Model::Build::Command::Base;

class Genome::Model::Build::Command::Base {
    is          => 'Genome::Command::Base',
    is_abstract => 1,
    has         => [
        builds => {
            is                  => 'Genome::Model::Build',
            is_many             => 1,
            shell_args_position => 1,
            doc =>
              'Build(s) to use. Resolved from command line via text string.',
        },
    ],
};

sub _limit_results_for_builds {
    my ( $class, @builds ) = @_;

    my $user = getpwuid($<);
    if ($user eq 'apipe') {
        print STDERR "Filtering any running builds from list...";
    }
    else {
        print STDERR "Filtering any builds not ran by $user from list...";
    }
    my @run_by_builds;
    for my $build (@builds) {
        if ($build->status eq 'Running' && $build->run_by && $build->run_by ne $user) {
            next;
        }
        if ($build->status ne 'Running' && $user ne 'apipe' && $build->run_by && $build->run_by ne $user) {
            next;
        }
        push @run_by_builds, $build;
    }
    my $other_users_builds_count = @builds - @run_by_builds;
    if ($user eq 'apipe') {
        if ($other_users_builds_count) {
            print STDERR " filtered $other_users_builds_count running builds.\n";
        }
        else {
            print STDERR " none filtered, no running builds.\n";
        }
    }
    else {
        if ($other_users_builds_count) {
            print STDERR " filtered $other_users_builds_count builds not ran by $user.\n";
        }
        else {
            print STDERR " none filtered, all builds ran by $user.\n";
        }
    }
    @builds = @run_by_builds;

    return @builds;
}

1;

