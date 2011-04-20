package Genome::Model::Tools::FastQual::Limit::ByCoverage;

use strict;
use warnings;

use Genome;            

require Carp;
use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Tools::FastQual::Limit::ByCoverage {
    is => 'Genome::Model::Tools::FastQual::Limit',
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
        stats => {
            is => 'Boolean',
            is_optional => 1,
            doc => 'Output stats.',
        },
    ],
};

sub help_synopsis {
    return <<HELP
    Limit sequences by total base coverage.
HELP
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    my $bases = $self->bases;
    my $count = $self->count;
    unless ( defined $bases or defined $count ) {
        $self->error_message("One coverage param (bases or count) is required");
        return;
    }

    if ( defined $bases ) {
        unless ( $bases =~ /^$RE{num}{int}$/ and $bases > 1 ) {
            $self->error_message("Invalid value ($bases) given for param 'bases'.");
            return;
        }
    }

    if ( defined $count ) {
        unless ( $count =~ /^$RE{num}{int}$/ and $count > 1 ) {
            $self->error_message("Invalid value ($count) given for param 'count'.");
            return;
        }
    }

    return $self;
}

sub execute {
    my $self = shift;

    my ($reader, $writer) = $self->_open_reader_and_writer;
    return if not $reader or not $writer;

    my @limiters;
    my $base_limiter = $self->_create_base_limiter;
    push @limiters, $base_limiter if $base_limiter;
    my $count_limiter = $self->_create_count_limiter;
    push @limiters, $count_limiter if $count_limiter;
    
    READER: while ( my $seqs = $reader->read ) {
        $writer->write($seqs);
        for my $limiter ( @limiters ) {
            last READER unless $limiter->($seqs); # returns 0 when done
        }
    }

    return 1;
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

