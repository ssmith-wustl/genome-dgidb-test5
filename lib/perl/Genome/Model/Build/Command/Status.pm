package Genome::Model::Build::Command::Status;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::Status {
    is => 'Genome::Command::Base',
    doc => "prints status of non-succeeded builds and tallies all build statuses",
    has => [
        builds => {
            is => 'Genome::Model::Build',
            is_many => 1,
            require_user_verify => 0,
            doc => 'Build(s) to check status. Resolved from command line via text string.',
            shell_args_position => 1,
        },
    ],
};

sub execute {
    my $self = shift;

    my %status;
    my @builds = sort {$a->model_name cmp $b->model_name} $self->builds;
    my $model_name;
    for my $build (@builds) {
        my $build_status = $build->status;
        $status{$build_status}++;
        if ($build_status ne 'Succeeded') {
            if (!$model_name || $model_name ne $build->model_name) {
                $model_name = $build->model_name;
                $self->status_message("Model: ".$model_name);
            }
            $self->status_message("\t".$build->id."\t$build_status");
        }
    }

    my $total;
    for my $key (sort keys %status) {
        $total += $status{$key};
    }

    for my $key (sort keys %status) {
        print "$key: $status{$key}\t";
    }
    print "Total: $total\n";

    return 1;
}

1;
