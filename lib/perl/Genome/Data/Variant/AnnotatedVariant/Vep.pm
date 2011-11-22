package Genome::Data::Variant::AnnotatedVariant::Vep;

use strict;
use warnings;
use Genome::Data::Variant::AnnotatedVariant;
use base 'Genome::Data::Variant::AnnotatedVariant';

sub create {
    my ($class, %params) = @_;
    my $self = $class->SUPER::create(%params);
    my @_annotation_fields = ();
    $self->{_annotation_fields} = \@_annotation_fields;
    my @_transcript_annotation_fields = qw(gene feature feature_type consequence cDNA_position CDS_position Protein_position Amino_acids Codons Existing_variation CANONICAL HGNC ENSP HGVSc HGVSp SIFT PolyPhen Condel MATRIX HIGH_INF_POS);
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

