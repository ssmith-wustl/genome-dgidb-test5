package Genome::Data::Variant::AnnotatedVariant::Tgi;

use strict;
use warnings;
use Genome::Data::Variant::AnnotatedVariant;
use base 'Genome::Data::Variant::AnnotatedVariant';

sub create {
    my ($class, %params) = @_;
    my $self = $class->SUPER::create(%params);
    my @_annotation_fields = ();
    $self->{_annotation_fields} = \@_annotation_fields;
    my @_transcript_annotation_fields = qw(gene_name transcript_name transcript_species transcript_source transcript_version strand transcript_status trv_type c_position amino_acid_change ucsc_cons domain all_domains deletion_substructures transcript_error);
    $self->{_transcript_annotation_fields} = \@_transcript_annotation_fields;
    return(bless($self, $class));
}

sub get_annotation_fields {
    my $self = shift;
    return $self->{_annotation_fields};
}

sub get_transcript_annotation_fields {
    my $self = shift;
    return $self->{_transcript_annotation_fields};
}

1;

