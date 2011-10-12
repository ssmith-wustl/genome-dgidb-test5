package Genome::Data::Variant;

use strict;
use warnings;

use Genome::Data;
use base 'Genome::Data';

use Carp;

sub create {
    my ($class, %params) = @_;
    my $self = {};
    bless($self, $class);
    $self->chrom(delete $params{chrom});
    $self->start(delete $params{start});
    $self->end(delete $params{end});
    $self->id(delete $params{id});
    $self->reference_allele(delete $params{reference_allele});
    $self->alt_alleles(delete $params{alt_alleles}); 
    $self->qual(delete $params{qual});

    if (%params) {
        Carp::confess "Extra parameters provided to constructor of " . __PACKAGE__;
    }
    return $self;
}

sub chrom {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_chrom} = $value;
    }
    return $self->{_chrom};
}

sub start {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_start} = $value;
    }
    return $self->{_start};
}

sub end {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_end} = $value;
    }
    return $self->{_end};
}

sub id {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_id} = $value;
    }
    return $self->{_id};
}

sub reference_allele {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_reference_allele} = $value;
    }
    return $self->{_reference_allele};
}

sub alt_alleles {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_alt_alleles} = $value;
    }
    return $self->{_alt_alleles};
}

sub qual {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{_qual} = $value;
    }
    return $self->{_qual};
}
1;

