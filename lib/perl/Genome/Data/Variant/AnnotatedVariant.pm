package Genome::Data::Variant::AnnotatedVariant;

use strict;
use warnings;
use Genome::Data::Variant;
use base 'Genome::Data::Variant';

sub create {
    my ($class, %params) = @_;
    my %super_params = map {$_ => $params{$_} } qw(chrom start end id reference_allele alt_alleles qual);
    map {delete $params{$_} } qw(chrom start end id reference_allele alt_alleles qual);
    my $self = $class->SUPER::create(%super_params);
    $self->transcript_annotations(delete $params{transcript_annotations});
foreach my $key (keys(%params)) {
print "$key\n";
}
    if (%params) {
        Carp::confess "Extra parameters provided to constructor of " . __PACKAGE__;
    }
    return(bless($self, $class));
}

sub transcript_annotations {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_transcript_annotations} = $value;
    }
    return $self->{_transcript_annotations};
}
1;

