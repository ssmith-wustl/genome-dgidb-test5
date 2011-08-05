package Genome::Model::Command::Define::RnaSeq;

use strict;
use warnings;

use Genome;
use Mail::Sender;

class Genome::Model::Command::Define::RnaSeq {
    is => 'Genome::Model::Command::Define::Helper',
    has => [
        reference_sequence_build => {
#            is => 'Genome::Model::Build::ImportedReferenceSequence',
            doc => 'ID or name of the reference sequence to align against',
            default_value => 'NCBI-human-build36',
            is_input => 1,
        },
    ]
};

sub type_specific_parameters_for_create {
    my $self = shift;
    my $reference_sequence_build = $self->_get_reference_sequence_build;
    return unless $reference_sequence_build;
    return ( reference_sequence_build => $reference_sequence_build );
}

sub _get_reference_sequence_build {
    my $self = shift;

    my $rsb_identifier = $self->reference_sequence_build;
    unless ( $rsb_identifier )  {
        Carp::confess("No reference sequence build (or name or id) given");
    }

    # We may already have it
    if ( ref($rsb_identifier) ) {
        return $rsb_identifier;
    }

    # from cmd line - this dies if non found
    my @reference_sequence_builds = Genome::Command::Base->resolve_param_value_from_text($rsb_identifier, 'Genome::Model::Build::ImportedReferenceSequence');
    if ( @reference_sequence_builds == 1 ) {
        return $reference_sequence_builds[0];
    } elsif( scalar @reference_sequence_builds eq 0) {
        Carp::confess("No imported reference sequence builds found for identifier ($rsb_identifier).");
    }

    Carp::confess("Multiple imported reference sequence builds found for identifier ($rsb_identifier): ".join(', ', map { '"'.$_->__display_name__.'"' } @reference_sequence_builds ));
}

1;
