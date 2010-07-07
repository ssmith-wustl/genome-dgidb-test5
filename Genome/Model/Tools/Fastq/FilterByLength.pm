package Genome::Model::Tools::Fastq::FilterByLength;

use strict;
use warnings;

use Genome;            

use Regexp::Common;

class Genome::Model::Tools::Fastq::FilterByLength {
    is => 'UR::Object',
    has => 
    [
        filter_length => {
            is => 'Number',
            doc => 'the number of bases to filter',
            #default_value => 20,
        }    
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    # Validate filter length
    my $filter_length = $self->filter_length;
    unless ( defined $filter_length ) {
        $self->error_message();
        $self->delete;
        return;
    }

    unless ( $filter_length =~ /^$RE{num}{int}$/ and $filter_length > 1 ) {
        $self->error_message();
        $self->delete;
        return;
    }

    return $self;
}

sub filter {
    my ($self, $seq) = @_;
    my $filter_length = $self->filter_length;
    #TODO: check for sane filter length
    
    if (ref $seq eq 'ARRAY') {  # hardcode for now
        my $test = 1;
        for my $s (@$seq) {
            unless (length ($s->{seq}) > $filter_length) {
                $test = 0;
                last;
            }
        }
        return $seq if $test;
    }
    else {
        return $seq if length ($seq->{seq}) > $filter_length;
    }

    return;
}

1;

#$HeadURL$
#$Id$
