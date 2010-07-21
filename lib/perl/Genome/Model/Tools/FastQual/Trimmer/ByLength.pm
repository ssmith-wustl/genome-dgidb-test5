package Genome::Model::Tools::FastQual::Trimmer::ByLength;

use strict;
use warnings;

use Genome;            

use Regexp::Common;

class Genome::Model::Tools::FastQual::Trimmer::ByLength {
    is => 'Genome::Model::Tools::FastQual::Trimmer',
    has => [
        trim_length => {
            is => 'Number',
            doc => 'the number of bases to remove',
        }    
     ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    my $trim_length = $self->trim_length;
    unless ( defined $trim_length ) {
        $self->error_message("No trim length given.");
        $self->delete;
        return;
    }
    unless ( $trim_length =~ /^$RE{num}{int}$/ and $trim_length > 1 ) {
        $self->error_message("Trim length ($trim_length) must be a positive integer.");
        $self->delete;
        return;
    }

    return $self;
}

sub _trim {
    my ($self, $seqs) = @_;

    for my $s (@$seqs) {
        my $bases = $s->{seq};
        my $quals = $s->{qual};

        my $length = length($bases) - $self->trim_length;
        $length = 0 if $length < 0;

        $quals = substr($quals,0,$length);
        $bases = substr($bases,0,$length);

        $s->{seq}  = $bases;
        $s->{qual} = $quals;
    }

    return $seqs;
}

1;

#$HeadURL$
#$Id$
