package Genome::Data::Mapper::AnnotatedVariant;

use strict;
use warnings;
use Genome::Data::Mapper;
use base 'Genome::Data::Mapper';

sub map_object {
    my $self = shift;
    my ($variant) = @_;
    ($self->get_new_object())->chrom($variant->chrom);
    ($self->get_new_object())->start($variant->start);
    ($self->get_new_object())->end($variant->end);
    ($self->get_new_object())->reference_allele($variant->reference_allele);
    ($self->get_new_object())->alt_alleles($variant->alt_alleles);
    ($self->get_new_object())->annotations({});
    ($self->get_new_object())->type($variant->type);
    my @old_transcript_annotations = @{$variant->transcript_annotations};
    my $annotation_fields = ($self->get_new_object())->get_annotation_fields();
    my $transcript_annotation_fields = ($self->get_new_object())->get_transcript_annotation_fields();

    my %new_annotations;
    foreach my $annotation_field (@$annotation_fields) {
        $new_annotations{$annotation_field} = $self->calculate_annotation_field($annotation_field, $variant->annotations);
    }
    ($self->get_new_object())->annotations(\%new_annotations);
    
    my %new_t_annotation;
    my @new_t_annotations;
    foreach my $t_annotation (@old_transcript_annotations) {
        foreach my $transcript_annotation_field (@$transcript_annotation_fields) {
            $new_t_annotation{$transcript_annotation_field} = $self->calculate_transcript_annotation_field($transcript_annotation_field, $t_annotation, $variant);
        }
        push(@new_t_annotations, \%new_t_annotation);
    }
    ($self->get_new_object())->transcript_annotations(\@new_t_annotations);
    return $self->get_new_object();
}

sub calculate_annotation_field {
    die ("calculate_annotation_field must be implemented by child class");
}

sub calculate_transcript_annotation_field {
    die ("calculate_transcript_annotation_field must be implemented by child class");
}

1;

