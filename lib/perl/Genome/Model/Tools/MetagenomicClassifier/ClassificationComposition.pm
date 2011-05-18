package Genome::Model::Tools::MetagenomicClassifier::ClassificationComposition;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::MetagenomicClassifier::ClassificationComposition {
    has => [
        confidence_threshold => {
            is => 'Number',
            doc => 'The confidence threshold that the classifications must be greter than or equal to to be considered confident.',
        },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my $threshold = $self->confidence_threshold;
    if ( not $threshold or $threshold > 1 or $threshold <= 0 ) {
        $self->error_message('Invalid confidence threshold: '.$threshold);
        return;
    }

    $self->{_classifications} = [];
    
    return $self;
}

sub add_classification {
    my ($self, $classification) = @_;

    my ($root_taxon) = grep { $_->{rank} eq 'root' } @{$classification->{taxa}};
    Carp::confess('No root taxon found in classification: '.Data::Dumper::Dumper($classification)) if not $root_taxon;

    my $i = ( $root_taxon->{confidence} >= $self->confidence_threshold ) ? 1 : 0;
    
    push @{$self->{_classifications}}, $classification;
    
    return 1;
}

sub confident_classifications {
    return $_[0]->{_classifications};
}

sub get_counts_for_domain_down_to_rank {
    my ($self, $domain, $to_rank) = @_;

    my $valid_domain = Genome::Model::Tools::MetagenomicClassifier->is_domain_valid($domain);
    return if not $valid_domain;

    my $valid_rank = Genome::Model::Tools::MetagenomicClassifier->is_rank_valid($to_rank);
    return if not $valid_rank;

    my @ranks;
    for my $rank ( Genome::Model::Tools::MetagenomicClassifier->taxonomic_ranks ) {
        push @ranks, $rank;
        last if $rank eq $to_rank;
    }

    my %counts;
    my $threshold = $self->confidence_threshold;
    for my $classification ( @{$self->confident_classifications} ) {
        my ($domain_taxon) = grep { $_->{rank} eq 'domain' } @{$classification->{taxa}};
        next if not $domain_taxon or lc($domain_taxon->{id}) ne $domain;
        my $taxonomy = join(
            ':', 
            grep { defined } map { $self->_get_name_from_classification_for_rank($classification, $_) } @ranks
        );
        # Increment total
        $counts{$taxonomy}->{total}++;
        # Go thru the ranks
        for my $rank ( @ranks ) {
            my $confidence = $self->_get_confidence_from_classification_for_rank($classification, $rank)
                or next;
            if ( $confidence >= $threshold ) {
                $counts{$taxonomy}->{$rank}++;
            }
            elsif ( not defined $counts{$taxonomy}->{$rank} ) {
                $counts{$taxonomy}->{$rank} = 0;
            }
        }
    }

    return %counts;
}

sub _get_name_from_classification_for_rank {
    my ($self, $classification, $rank) = @_;
    my ($taxon) = grep { $_->{rank} eq $rank } @{$classification->{taxa}};
    return $taxon->{id};
}

sub _get_confidence_from_classification_for_rank {
    my ($self, $classification, $rank) = @_;
    my ($taxon) = grep { $_->{rank} eq $rank } @{$classification->{taxa}};
    return $taxon->{confidence};
}

1;

