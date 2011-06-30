package Genome::Model::Tools::Sx::Limit::ByCoverage;

use strict;
use warnings;

use Genome;            

use Regexp::Common;

class Genome::Model::Tools::Sx::Limit::ByCoverage {
    is => 'Genome::Model::Tools::Sx::Limit',
    has => [
        bases => {
            is => 'Number',
            is_optional => 1,
            doc => 'The maximum number of bases (for each sequence) to write. When this amount is exceeded, writing will be concluded.',
        },
        count => {
            is => 'Number',
            is_optional => 1,
            doc => 'The maximum number of sequences to write. When this amount is exceeded, writing will be concluded.',
        },
    ],
};

sub help_synopsis {
    return 'Limit sequences by bases and/or count';
}

sub __errors__ {
    my $self = shift;

    my @errors = $self->SUPER::__errors__(@_);
    return @errors if @errors;

    my $bases = $self->bases;
    my $count = $self->count;
    if ( not defined $bases and not defined $count ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ bases count /],
            desc => 'Must specify at least one coverage param: bases or count',
        );
    }

    if ( defined $bases and ( $bases !~ /^$RE{num}{int}$/ or $bases < 1 ) ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ bases /],
            desc => "Bases ($bases) must be a positive integer greater than 1",
        );
    }

    if ( defined $count and ( $count !~ /^$RE{num}{int}$/ or $count < 1 ) ) {
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

    my @limiters;
    my $base_limiter = $self->_create_base_limiter;
    push @limiters, $base_limiter if $base_limiter;
    my $count_limiter = $self->_create_count_limiter;
    push @limiters, $count_limiter if $count_limiter;

    return @limiters;
}

sub _create_base_limiter { 
    my $self = shift;

    my $bases = $self->bases;
    return unless defined $bases;

    return sub{
        for my $seq ( @{$_[0]} ) { 
            $bases -= length($seq->{seq});
        }
        return ( $bases > 0 ) ? 1 : 0 ;
    };
}

sub _create_count_limiter { 
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

