package Genome::Data::Variant::AnnotatedVariant;

use strict;
use warnings;
use Genome::Data::Variant;
use base 'Genome::Data::Variant';

sub create {
    my ($class, %params) = @_;
    my @super_fields = qw(chrom start end reference_allele alt_alleles annotations);
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

#annotations are key-value pairs that relate to the variant as a whole
sub annotations {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_annotations} = $value;
    }
    return $self->{_annotations};
}

#transcript annotations connect a specific feature with a variant
#each transcript annotation is a hash
sub transcript_annotations {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_transcript_annotations} = $value;
    }
    return $self->{_transcript_annotations};
}
1;

