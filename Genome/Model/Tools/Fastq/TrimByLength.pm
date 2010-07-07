package Genome::Model::Tools::Fastq::TrimByLength;

use strict;
use warnings;

use Genome;            

use Regexp::Common;

class Genome::Model::Tools::Fastq::TrimByLength {
    is => 'UR::Object',
    has => 
    [
        trim_length => {
            is => 'Number',
            doc => 'the number of bases to remove',
            #default_value => 20,
        }    
     ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    # Validate trim length
    my $trim_length = $self->trim_length;
    unless ( defined $trim_length ) {
        $self->error_message();
        $self->delete;
        return;
    }

    unless ( $trim_length =~ /^$RE{num}{int}$/ and $trim_length > 1 ) {
        $self->error_message();
        $self->delete;
        return;
    }

    return $self;
}


sub trim {
    my ($self, $seq) = @_;
    
    if (ref $seq eq 'ARRAY') {
        my $trim_seq = [];

        for my $s (@$seq) {
            push @$trim_seq, $self->_trim_seq($s);
        }
        return $trim_seq;
    }
    else {
        return $self->_trim_seq($seq);
    }
}


sub _trim_seq {
    my ($self, $seq) = @_;
    my $bases = $seq->{seq};
    my $quals = $seq->{qual};
    
    my $trim_length = $self->trim_length;

    my $length = length($bases) - $trim_length;
    $length = 0 if $length < 0;
    
    $quals = substr($quals,0,$length);
    $bases = substr($bases,0,$length);
    
    $seq->{seq}  = $bases;
    $seq->{qual} = $quals;
    
    return $seq;
    
}

1;

#$HeadURL$
#$Id$
