#:boberkfe seems like execute and verify successful completion could be
#:boberkfe pulled up to the superlass

package Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Blat;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Blat {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::AlignReads'],
};

sub execute {
    my $self = shift;
    my $instrument_data_assignment = $self->instrument_data_assignment;
    my $alignment = $instrument_data_assignment->alignment;
    unless ($alignment->find_or_generate_alignment_data) {
        $self->error_message("Error finding or generating alignments!:\n" .  join("\n",$alignment->error_message));
        return;
    }
    unless ($self->verify_successful_completion) {
        $self->error_message("Error verifying completion!");
        return;
    }
    return 1;
}



sub verify_successful_completion {
    my $self = shift;
    my $instrument_data_assignment = $self->instrument_data_assignment;
    my $alignment = $instrument_data_assignment->alignment;
    unless ($alignment->verify_alignment_data) {
        $self->error_message('Failed to verify alignment data');
        return;
    }
    return 1;
}


1;

