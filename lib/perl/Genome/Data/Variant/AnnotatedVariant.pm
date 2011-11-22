package Genome::Data::Variant::AnnotatedVariant;

use strict;
use warnings;
use Genome::Data::Variant;
use base 'Genome::Data::Variant';

sub create {
    my ($class, %params) = @_;
    my @super_fields = qw(type chrom start end reference_allele alt_alleles annotations);
    my %super_params = map {$_ => $params{$_} } @super_fields;
    map {delete $params{$_} } @super_fields;
    my $self = $class->SUPER::create(%super_params);
    $self->transcript_annotations(delete $params{transcript_annotations});
    $self->annotations(delete $params{annotations});

    if (%params) {
        Carp::confess "Extra parameters provided to constructor of " . __PACKAGE__;
    }
    return(bless($self, $class));
}

#transcript annotations connect a specific feature with a variant
#each transcript annotation is a hash
#TODO: verify that fields from get_transcript_annotation_fields are present and no others
sub transcript_annotations {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_transcript_annotations} = $value;
    }
    return $self->{_transcript_annotations};
}

sub get_transcript_annotation_fields {
    die ("get_transcript_annotation_fields must be implemented by child class");
}
1;
