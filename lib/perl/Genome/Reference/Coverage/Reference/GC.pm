package Genome::Reference::Coverage::Reference::GC;

use strict;
use warnings;

use Genome;

my @ALPHABET = qw/a t g c n/;
my @PAIRINGS = qw/at gc/;
my @METRIC_CATEGORIES = qw/raw reflen covlen uncovlen/;
my @METRIC_TYPES = qw/bp percent/;

class Genome::Reference::Coverage::Reference::GC {
    has => [
        coverage => {
            is => 'ArrayRef',
            doc => 'An array reference of integers representing depth at each base position.',
        },
        sequence => {
            is => 'ArrayRef',
            doc => 'An array reference of sequence that corresponds to the coverage array ref positions',
        },
        # TODO: Shouldn't checking the length of each array ref be sufficient...
        reflen => {
            is => 'Integer',
            doc => '',
        },
        covlen => {
            is_optional => 1,
            default_value => 0,
        },
        uncovlen => {
            is_optional => 1,
            default_value => 0,
        },
    ],
    has_optional => {
        a_hash_ref => { },
        t_hash_ref => { },
        g_hash_ref => { },
        c_hash_ref => { },
        n_hash_ref => { },
        at_hash_ref => { },
        gc_hash_ref => { },
    },
};

sub create {
    my $class = shift;
    my %params = @_;
    my $coverage = delete($params{coverage});
    my $sequence = delete($params{sequence});
    my $self = $class->SUPER::create(%params);
    $self->coverage($coverage);
    $self->sequence($sequence);
    for my $category ($self->alphabet, $self->base_pairings) {
        my %hash = ();
        for my $metric_category ($self->metric_categories) {
            for my $metric_type ($self->metric_types) {
                my $key = $metric_category .'_'. $metric_type;
                $hash{$key} = 0;
            }
        }
        my $accessor = $category .'_hash_ref';
        $self->$accessor(\%hash);
    }
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

    # ** NOTE **
    # Thu Jun 17 23:15:03 CDT 2010
    # We will attempt all calculation updates in one pass. However, this may
    # prove to be computationally costly and might not scale well. We may wish
    # to isolate just the GC metrics in the future. We slice right into the
    # coverage and sequence arrays by field on purpose (i.e., no accessor here)
    # to save computation time and be faster.

    # MAIN CALCULATIONS LOGIC FOLLOWS THIS LINE
    # _____________________________________________________________________________

    my $end = ($self->reflen() - 1);

    for (0 .. $end) {
        my $pos = $_;
        my $hash_key;
        if ($self->coverage->[$pos] > 0) {
            # Coverage.
            $self->_covlen_increment();
            $hash_key = 'covlen_bp';
        } elsif ($self->coverage->[$pos] == 0) {
            # No coverage.
            $self->_uncovlen_increment();
            $hash_key = 'uncovlen_bp';
        } else {
            die('Negative coverage?  Something bad just happened.');
        }
        my $match = 0;
        for my $base ($self->alphabet) {
            if ($self->sequence->[$pos] =~ /$base/i) {
                $self->_increment_hash_key($base,'raw_bp');
                # TODO: Not sure why, but this was the prior behavior
                if ($hash_key eq 'covlen_bp') {
                    $self->_increment_hash_key($base,'reflen_bp');
                }
                $self->_increment_hash_key($base,$hash_key);
                $match = 1;
            }
        }
        unless ($match) {
            die (__PACKAGE__ .' unknown nucleotide '. $self->sequence->[$pos] .' passed.');
        }
    }
    return $self;
}

sub _update_base_pair_values {
    my $self = shift;
    for my $base_pair ($self->base_pairings) {
        my @bases = split('',$base_pair);
        for my $base (@bases) {
            for my $metric_category ($self->metric_categories) {
                my $key = $metric_category .'_bp';
                my $base_value = $self->_get_base_hash_ref_value_by_key($base,$key);
                $self->_increment_hash_key($base_pair,$key,$base_value);
            }
        }
    }
}


sub _update_all_percent_values {
    my $self = shift;

    for my $category ($self->alphabet,$self->base_pairings) {
        for my $metric_category ($self->metric_categories) {
            my $bp_key = $metric_category .'_bp';
            my $percent_key = $metric_category .'_percent';
            # Percent of reflen that is A (RAW).
            my $denominator_method;
            if ($metric_category eq 'reflen' || $metric_category eq 'raw') {
                $denominator_method = 'reflen';
            } else {
                $denominator_method = $metric_category;
            }
            my $pct = 0;
            if ($self->$denominator_method) {
                $pct = _round( ($self->_get_base_hash_ref_value_by_key($category,$bp_key) / $self->$denominator_method ) * 100 );
            }
            $self->_increment_hash_key($category,$percent_key,$pct);
        }
    }

    return $self;
}


sub _covlen_increment {
    my $self = shift;
    my $covlen = $self->covlen;
    $covlen++;
    $self->covlen($covlen);
}

sub _uncovlen_increment {
    my $self = shift;
    my $uncovlen = $self->uncovlen;
    $uncovlen++;
    $self->uncovlen($uncovlen);
}

sub _get_base_hash_ref_value_by_key {
    my $self = shift;
    my $base = shift;
    my $key = shift;
    my $method = $base .'_hash_ref';
    my $hash_ref = $self->$method;
    my $value = $hash_ref->{$key};
    return $value;
}

sub _increment_hash_key {
    my $self = shift;
    my $category = shift;
    my $key = shift;
    my $value = shift;

    unless (defined($value)) { $value = 1; }

    my $method = $category .'_hash_ref';
    my $hash_ref = $self->$method;
    $hash_ref->{$key} += $value;
    $self->$method($hash_ref);
    return 1;
}


sub _round {
    my $value = shift;
    return sprintf( "%.2f", $value );
}


1;  # End of package.

__END__
