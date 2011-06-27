package Genome::Model::Tools::Sx::Trimmer::ByLength;

use strict;
use warnings;

use Genome;            

use Regexp::Common;

class Genome::Model::Tools::Sx::Trimmer::ByLength {
    is => 'Genome::Model::Tools::Sx::Trimmer',
    has_optional => [
        trim_length => {
            is => 'Integer',
            doc => 'the number of bases to remove',
        },    
        read_length => {
            is => 'Integer',
            doc => 'the number of bases to keep',
        }    
     ],
};

sub __errors__ {
    my $self = shift;
    my @errors = $self->SUPER::__errors__(@_);
    return @errors if @errors;
    if ($self->trim_length and $self->read_length) {
        push @errors, 
            UR::Object::Tag->create(
                type => 'invalid',
                properties => ['trim_length','read_length'],
                desc => "trim_length and read_length cannot both be specified"
            );
    }
    elsif (!$self->trim_length and !$self->read_length) {
        push @errors, 
            UR::Object::Tag->create(
                type => 'invalid',
                properties => ['trim_length','read_length'],
                desc => "either trim_length or read_length must be specified"
            );
    }
    if ( $self->trim_length and ( $self->trim_length !~ /^$RE{num}{int}$/ or $self->trim_length < 1 ) ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ trim_length /],
            desc => 'Trim length is not a integer greater than 0 => '.$self->trim_length,
        );
    }
    elsif ( $self->read_length and ( $self->read_length !~ /^$RE{num}{int}$/ or $self->read_length < 1 ) ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ read_length /],
            desc => 'Read length is not a integer greater than 0 => '.$self->read_length,
        );
    }
    return @errors;
}

sub _trim {
    my ($self, $seqs) = @_;

    # if read_length is specified, we'll trim all reads down to that length 
    # where they are longer
    my $length = $self->read_length;

    # if trim_length is specified that many bases will be removed
    # (the actual read length will vary in the output if it varies in the input)
    my $trim_length = $self->trim_length;

    for my $s (@$seqs) {
        my $bases = $s->{seq};
        my $quals = $s->{qual};

        if ($trim_length) {
            $length = length($bases) - $trim_length;
            $length = 0 if $length < 0;
        }

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
