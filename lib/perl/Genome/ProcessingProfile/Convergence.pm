package Genome::ProcessingProfile::Convergence;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Convergence{
    is => 'Genome::ProcessingProfile',
    has_param => [
    ],
};

sub _resolve_workflow_for_build {
    my $self = shift;
    my $build = shift;

    my $operation = Workflow::Operation->create_from_xml(__FILE__ . '.xml');

    my $log_directory = $build->log_directory;
    $operation->log_dir($log_directory);
    $operation->name($build->workflow_name);

    return $operation;
}

sub _map_workflow_inputs {
    my $self = shift;
    my $build = shift;

    my @inputs = ();

    my @members = $build->members;

    #Check that the members are ready for convergence
    for my $member (@members) {
         unless($member->status eq 'Succeeded') {
            $self->error_message("Tried to use non-succeeded build! " . $member->id);
            return;
        }
    } 

    my $data_directory = $build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        return;
    }

    #Assign filenames
    my %default_filenames = $self->default_filenames;
    for my $parameter (keys %default_filenames) {
        push @inputs,
            $parameter => ($data_directory . "/" . $default_filenames{$parameter});
    }

    push @inputs,
        build_id => $build->id,
        skip_if_output_present => 1;

    return @inputs;
}

sub default_filenames{
    my $self = shift;

    my %default_filenames = (
    );

    return %default_filenames;
}

1;

