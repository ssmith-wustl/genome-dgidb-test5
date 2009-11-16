#:boberkfe seems like execute and verify successful completion could be
#:boberkfe pulled up to the superlass

package Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Blat;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Blat {
    is => [
        'Genome::Model::Command::Build::ReferenceAlignment::AlignReads',
    ],
};

sub help_brief {
    "Use blat to align instrument data reads";
}

sub help_synopsis {
    return <<"EOS"
    genome model build reference-alignment align-reads blat --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the build process
EOS
}

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

