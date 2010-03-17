package Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Novocraft;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Novocraft {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::AlignReads'],
	has => [
    ],
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[tmp=90000:mem=8000]' -M 8000000 -n 4";
}

sub execute {
    my $self = shift;

    print Data::Dumper::Dumper($self);

    #old AssignRun step 
    unless (-d $self->build_directory) {
        $self->create_directory($self->build_directory);
        $self->status_message("Created build directory: ".$self->build_directory);
    } else {
        $self->status_message("Build directory exists: ".$self->build_directory);
    }

    # undo any changes from a prior run
    $self->revert;

    my $instrument_data_assignment = $self->instrument_data_assignment;
    my @alignments = $instrument_data_assignment->alignments;
    my @errors;
    for my $alignment (@alignments) {
        # ensure the alignments are present
        $alignment->lock_alignment_resource;
        unless ($alignment->find_or_generate_alignment_data) {
            $self->error_message("Error finding or generating alignments!:\n" .  join("\n",$alignment->error_message));
            push @errors, $self->error_message;
        }
    }
    if (@errors) {
        $self->error_message(join("\n",@errors));
        return 0;
    }
    unless ($self->verify_successful_completion) {
        $self->error_message("Error verifying completion!");
        return 0;
    }
    for my $alignment (@alignments) {
        $alignment->unlock_alignment_resource;
    }

    return 1;
}

sub verify_successful_completion {
    my $self = shift;

    unless (-d $self->build_directory) {
    	$self->error_message("Build directory does not exist: " . $self->build_directory);
        return 0;
    }

    my $instrument_data_assignment = $self->instrument_data_assignment;
    my @alignments = $instrument_data_assignment->alignments;
    my @errors;
    for my $alignment (@alignments) {
        unless ($alignment->verify_alignment_data) {
            $self->error_message('Failed to verify alignment data: '.  join("\n",$alignment->error_message));
            push @errors, $self->error_message;
        }
    }
    if (@errors) {
        $self->error_message(join("\n",@errors));
        return 0;
    }

    return 1;
}

1;
