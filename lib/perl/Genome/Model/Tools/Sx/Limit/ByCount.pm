package Genome::Model::Tools::Sx::Limit::ByCount;

use strict;
use warnings;

use Genome;            

use Regexp::Common;

class Genome::Model::Tools::Sx::Limit::ByCount {
    is => 'Genome::Model::Tools::Sx::Limit',
    has => [
        count => {
            is => 'Number',
            is_optional => 1,
            doc => 'The maximum number of sequences to write. When this amount is exceeded, writing will be concluded.',
        },
    ],
};

sub help_synopsis {
    return 'Limit sequences by count';
}

sub __errors__ {
    my $self = shift;

    my @errors = $self->SUPER::__errors__(@_);
    return @errors if @errors;

    my $count = $self->count;
    if ( not defined $count or $count !~ /^$RE{num}{int}$/ or $count < 1 ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ count /],
            desc => "Count ($count) must be a positive integer greater than 1",
        );
    }

    return @errors;
}

sub _create_limiters { 
    my $self = shift;

    my $count = $self->count;
    return unless defined $count;

    return sub{
        my $seqs = shift;
        $count -= scalar(@$seqs);
        return ( $count > 0 ) ? 1 : 0 ;
    };
}

1;

