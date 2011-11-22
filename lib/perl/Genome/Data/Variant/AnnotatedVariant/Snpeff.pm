package Genome::Data::Variant::AnnotatedVariant::Snpeff;

use strict;
use warnings;
use Genome::Data::Variant::AnnotatedVariant;
use base 'Genome::Data::Variant::AnnotatedVariant';

sub create {
    my ($class, %params) = @_;
    my $self = $class->SUPER::create(%params);
    my @_annotation_fields = qw(qual id);
    $self->{_annotation_fields} = \@_annotation_fields;
    my @_transcript_annotation_fields = qw(effect effect_impact codon_change amino_acid_change gene_name gene_biotype coding transcript exon errors warnings);
    $self->{_transcript_annotation_fields} = \@_transcript_annotation_fields;
    return(bless($self, $class));
}

sub get_annotation_fields {
    my $self = shift;
    return $self->_annotation_fields;
}

sub get_transcript_annotation_fields {
    my $self = shift;
    return $self->_transcript_annotation_fields;
}

1;

