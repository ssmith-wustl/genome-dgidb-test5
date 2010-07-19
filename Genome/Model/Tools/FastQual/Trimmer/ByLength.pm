package Genome::Model::Tools::FastQual::Trimmer::ByLength;

use strict;
use warnings;

use Genome;            

use Regexp::Common;

class Genome::Model::Tools::FastQual::Trimmer::ByLength {
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
    my $trim_length = $self->trim_length;
    
    if (ref $seq eq 'ARRAY') {
        for my $s (@$seq) {
            my $bases = $s->{seq};
            my $quals = $s->{qual};

            my $length = length($bases) - $trim_length;
            $length = 0 if $length < 0;

            $quals = substr($quals,0,$length);
            $bases = substr($bases,0,$length);
    
            $s->{seq}  = $bases;
            $s->{qual} = $quals;
        }
        return $seq;
    }
    else {
        $self->error_message('Wrong fastq input type, must be array ref');
        return;
    }
}


1;

#$HeadURL$
#$Id$
