package Genome::RefCov::Reference::GC;

use strict;
use warnings;

use Genome;

my @ALPHABET = qw/a t g c n/;
my @PAIRINGS = qw/at gc/;
my @METRIC_CATEGORIES = qw/reflen covlen uncovlen/;
my @METRIC_TYPES = qw/bp percent/;

class Genome::RefCov::Reference::GC {
    has => [
        coverage => {
            is => 'ArrayRef',
            doc => 'An array reference of integers representing depth at each base position.',
        },
        sequence => {
            is => 'ArrayRef',
            doc => 'An array reference of sequence that corresponds to the coverage array ref positions',
        },
        _reflen => {
            is_optional => 1,
            default_value => 0,
        },
        _covlen => {
            is_optional => 1,
            default_value => 0,
        },
        _uncovlen => {
            is_optional => 1,
            default_value => 0,
        },
    ],
    has_optional => {
        metrics_hash_ref => { },
    },
};

sub create {
    my $class = shift;
    my %params = @_;
    my $coverage = delete($params{coverage});
    my $sequence = delete($params{sequence});
    unless ($coverage && $sequence) {
        die('A coverage and sequence array ref is required!');
    }
    unless (scalar(@{$coverage}) == scalar(@{$sequence})) {
        die('The coverage('. scalar(@{$coverage}) .') and sequence('.  scalar(@{$sequence}) .') array ref length must match!');
    }
    my $self = $class->SUPER::create(%params);
    $self->coverage($coverage);
    $self->sequence($sequence);
    $self->_reflen(scalar(@{$coverage}));
    my %hash = ();
    for my $metric_category ($self->metric_categories) {
        for my $metric_type ($self->metric_types) {
            my $key = $metric_category .'_'. $metric_type;
            $hash{$key} = {};
        }
    }
    $self->metrics_hash_ref(\%hash);

    # Update the object instance with calculations.
    $self->_update_all_base_values();
    $self->_update_base_pair_values();
    $self->_update_all_percent_values();

    return $self;
}

sub alphabet {
    return @ALPHABET;
}

sub base_pairings {
    return @PAIRINGS;
}

sub metric_categories {
    return @METRIC_CATEGORIES;
}

sub metric_types {
    return @METRIC_TYPES;
}

sub _update_all_base_values {
    my $self = shift;

    my $hash_ref = $self->metrics_hash_ref;
    my $coverage = $self->coverage;
    my $sequence = $self->sequence;
    my $covlen = 0;
    my $uncovlen = 0;
    for (my $i=0; $i < scalar(@{$coverage}); $i++) {
        my $depth = $coverage->[$i];
        my $base = $sequence->[$i];
        $hash_ref->{'reflen_bp'}->{$base}++;
        if ($depth > 0) {
            # Coverage.
            $covlen++;
            $hash_ref->{'covlen_bp'}->{$base}++;
        } else {
            # No Coverage.
            $uncovlen++;
            $hash_ref->{'uncovlen_bp'}->{$base}++;
        }
    }
    $self->_covlen($covlen);
    $self->_uncovlen($uncovlen);
    $self->metrics_hash_ref($hash_ref);
    return $self;
}

sub _update_base_pair_values {
    my $self = shift;
    my $hash_ref = $self->metrics_hash_ref;
    for my $base_pair ($self->base_pairings) {
        my @bases = split('',$base_pair);
        for my $base (@bases) {
            for my $metric_category ($self->metric_categories) {
                my $key = $metric_category .'_bp';
                $hash_ref->{$key}->{$base_pair} += ($hash_ref->{$key}->{$base} || 0);
            }
        }
    }
    $self->metrics_hash_ref($hash_ref);
}

sub _update_all_percent_values {
    my $self = shift;
    my $hash_ref = $self->metrics_hash_ref;
    for my $category ($self->alphabet,$self->base_pairings) {
        for my $metric_category ($self->metric_categories) {
            my $bp_key = $metric_category .'_bp';
            my $percent_key = $metric_category .'_percent';
            my $pct = 0;
            my $denominator = '_'. $metric_category;
            if ($self->$denominator) {
                my $value = $hash_ref->{$bp_key}->{$category} || 0;
                $pct = _round( ($value / $self->$denominator ) * 100 );
            }
            $hash_ref->{$bp_key}->{$category} = $pct;
        }
    }
    $self->metrics_hash_ref($hash_ref);
    return $self;
}

sub _round {
    my $value = shift;
    return sprintf( "%.2f", $value );
}

sub nucleotide_hash_ref {
    my $self = shift;
    my $nucleotide = shift;
    my $hash_ref = $self->metrics_hash_ref;
    my %hash;
    for my $key (keys %{$hash_ref}) {
        $hash{$nucleotide .'_'. $key} = $hash_ref->{$key}->{$nucleotide};
    }
    return \%hash;
}

sub gc_hash_ref {
    my $self = shift;
    return $self->nucleotide_hash_ref('gc');
}

1;  # End of package.

__END__
