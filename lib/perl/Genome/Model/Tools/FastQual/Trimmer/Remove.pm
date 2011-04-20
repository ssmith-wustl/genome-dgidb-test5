package Genome::Model::Tools::FastQual::Trimmer::Remove;

use strict;
use warnings;

use Genome;            

use Regexp::Common;

class Genome::Model::Tools::FastQual::Trimmer::Remove {
    is => 'Genome::Model::Tools::FastQual::Trimmer',
    has => [
        length => {
            is => 'Integer',
            doc => 'The number of bases to remove.',
        },    
     ],
};

sub help_brief {
    return 'Trim a set length off of a sequence';
}

sub __errors__ {
    my $self = shift;
    my @errors = $self->SUPER::__errors__(@_);
    return @errors if @errors;
    if ( $self->length !~ /^$RE{num}{int}$/ or $self->length < 1 ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ length /],
            desc => 'The remove length (length) is not a integer greater than 0 => '.$self->length,
        );
    }
    return @errors;
}

sub _trim {
    my ($self, $seqs) = @_;

    for my $seq ( @$seqs ) {
        my $length = length($seq->{seq}) - $self->length;
        next if $length eq 0;
        $seq->{seq} = substr($seq->{seq}, 0, $length);
        $seq->{qual} =substr($seq->{qual}, 0, $length);
    }

    return $seqs;
}

1;

