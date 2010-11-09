package Genome::Model::Command::Diff;

use strict;
use warnings;
use Genome;
use Carp 'confess';

class Genome::Model::Command::Diff {
    is => 'Genome::Command::Base',
    has => [
        models => {
            is => 'Genome::Model',
            require_user_verify => 0,
            shell_args_position => 1,
            is_many => 1,
            doc => 'Models that should have their builds compared',
        },
        first_revision => {
            is => 'Text',
            doc => 'Path to revision that one build was run on (eg, /gsc/scripts/opt/passed-model-tests/genome-###)',
        },
    ],
    has_optional => [
        second_revision => {
            is => 'Text',
            doc => 'Path to revision that other build was run on, defaults to /gsc/scripts/opt/genome-stable',
        },
    ],
};

sub hudson_build_from_revision {
    my ($self, $revision) = @_;
    if ($revision =~ /(genome-\d+)/) {
        return $1;
    }
    return $revision;
}

# Check that the revision ends with lib/perl and add it if its not there
sub check_and_fix_revision {
    my ($self, $revision) = @_;
    $revision .= '/lib/perl/' unless $revision =~ '/lib/perl';
    return $revision;
}

sub execute { 
    my $self = shift;

    my $first_revision = $self->check_and_fix_revision($self->first_revision);
    confess "Revision not found at $first_revision!" unless -d $first_revision;

    # Determine what the current genome-stable symlink points at if no second revision is given
    my $second_revision = $self->second_revision;
    unless (defined $second_revision) {
        my $stable_target = readlink '/gsc/scripts/opt/genome-stable';
        confess 'Could not readlink genome-stable symlink!' unless defined $stable_target;
        $second_revision = '/gsc/scripts/opt/' . $stable_target . '/lib/perl/';
        confess "No revision found at $second_revision!" unless -d $second_revision;
        $self->status_message("Not given second revision, using genome-stable at $second_revision");
    }
    else {
        confess "No revision found at $second_revision!" unless -d $second_revision;
    }
    $second_revision = $self->check_and_fix_revision($second_revision);

    if ($first_revision eq $second_revision) {
        confess "Comparing builds from $first_revision and $second_revision... these are the same, no point in comparing.";
    }

    $self->status_message("Comparing builds from revisions $first_revision and $second_revision");

    # If comparing hudson nightly builds, the software revision of the build with be /gsc/scripts/opt/passed-unit-tests*,
    # which no longer exists at this point because a successful model test results in the snapshot directory being moved
    # from passed-unit-tests to passed-model-tests. Using only the genome-### portion is good enough.
    my $fixed_first_revision = $self->hudson_build_from_revision($first_revision);
    my $fixed_second_revision = $self->hudson_build_from_revision($second_revision);
    for my $model ($self->models) {
        my $model_id = $model->genome_model_id;
        my $type = $model->class;
        $type =~ s/Genome::Model:://;
        next if $type =~ /Convergence/; # Talk to Tom for details... basically, there's no expectation that the output be
                                        # the same between builds, so diffing the output at all is pointless.
                                        
        my $type_string = Genome::Utility::Text::camel_case_to_string($type, '_');
        $self->status_message("\nWorking on model $model_id, type $type_string");

        # Find builds for each given revision
        my ($first_build, $second_build);
        my @builds = sort { $b->build_id <=> $a->build_id } $model->builds;
        for my $build (@builds) {
            last if $first_build and $second_build;
            my $build_revision = $build->software_revision;
            next unless defined $build_revision;
            if ($build_revision =~ /$fixed_first_revision/) {
                $first_build = $build;
            }
            elsif ($build_revision =~ /$fixed_second_revision/) {
                $second_build = $build;
            }
        }

        unless ($first_build and $second_build) {
            my $msg = "BUILD NOT FOUND $type_string $model_id: Could not find build for model $model_id using revision:";
            $msg .= ' ' . $first_revision unless $first_build;
            $msg .= ' ' . $second_revision unless $second_build;
            $self->warning_message($msg);
            next;
        }

        $self->status_message("Comparing build " . $first_build->build_id . " using revision $first_revision with build " . 
            $second_build->build_id . " using revision $second_revision from model $model_id");

        my %diffs = $first_build->compare_output($second_build->build_id);
        unless (%diffs) {
            $self->status_message("All files diffed cleanly!");
        }
        else {
            my $diff_string = "DIFFERENCES FOUND $type_string $model_id\n";
            for my $file (sort keys %diffs) {
                my $reason = $diffs{$file};
                $diff_string .= "  File: $file, Reason: $reason\n";
            }
            $self->status_message($diff_string);
        }
    }

    return 1;
}
1;  

