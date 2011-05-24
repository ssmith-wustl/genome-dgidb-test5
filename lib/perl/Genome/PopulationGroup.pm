package Genome::PopulationGroup;

use strict;
use warnings;

use Genome;

class Genome::PopulationGroup {
    is => 'Genome::Subject',
    has => [
        subject_type => { 
            is => 'Text', 
            is_constant => 1, 
            value => 'population group',
        },
        member_hash => {
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'member_hash' ],
            is_mutable => 1,
            doc => 'Makes it easier to figure out if another group with the exact set of individuals already exists',
        },
    ],
    has_many => [
        member_ids => {
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'member' ],
            is_mutable => 1,
        },
        members => { 
            is => 'Genome::Individual',
            via => 'attributes',
            to => '_individual',
            where => [ attribute_label => 'member' ],
        },
        samples => { 
            is => 'Genome::Sample', 
            reverse_id_by => 'source',
        },
        sample_names => {
            via => 'samples',
            to => 'name',
        },
    ],
    has_optional => [
        taxon_id => {
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'taxon_id' ],
            is_mutable => 1,
        },
        taxon => { 
            is => 'Genome::Taxon', 
            id_by => 'taxon_id', 
        },
        species_name => { via => 'taxon' },
    ],
    doc => 'a possibly arbitrary group of individual organisms',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    my $member_hash = $self->generate_hash_for_individuals($self->members);
    $self->member_hash($member_hash);
    return $self;
}

# Return any other population groups that have the same member hash as the one provided
sub existing_population_groups_with_hash {
    my ($self, $hash) = @_;
    return Genome::PopulationGroup->get(
        member_hash => $hash,
        'id ne' => $self->id,
    );
}

# Generate an md5 hash based on the ids of the provided individuals
sub generate_hash_for_individuals {
    my ($self, @individuals) = @_;
    my @ids = sort map { $_->id } @individuals;
    # Returns a valid answer even if individuals is undef
    my $hash = Digest::MD5::md5_hex(@ids);
    return $hash;
}

# Filter the provided list of individuals to include only unique individuals not already in the group
sub remove_non_unique_individuals {
    my ($self, @individuals) = @_;

    my %unique;
    map { $unique{$_->id} = $_ } @individuals;

    for my $member_id ($self->member_ids) {
        delete $unique{$member_id} if exists $unique{$member_id};
    }

    return values %unique;
}

sub add_member {
    my ($self, $individual) = @_;
    return $self->add_members($individual);
}

# Filters the given list of individuals and adds any that pass filtering to the group
sub add_members {
    my ($self, @individuals) = @_;
    my @addable_individuals = $self->remove_non_unique_individuals(@individuals);
    return 1 unless @addable_individuals; # If all of the provided individuals are already added/redundant, just do nothing

    for my $addable (@addable_individuals) {
        my $attribute = Genome::SubjectAttribute->create(
            attribute_label => 'member',
            attribute_value => $addable->id,
            subject_id => $self->id,
        );
        unless ($attribute) {
            Carp::confess "Could not add individual " . $addable->id . " to population group " . $self->id;
        }
    }

    my $member_hash = $self->generate_hash_for_individuals($self->members);
    $self->member_hash($member_hash);
    return 1;
}

# Removes members from the group
sub remove_members {
    my ($self, @individuals) = @_;
    my @removed;
    for my $individual (@individuals) {
        my $attribute = Genome::SubjectAttribute->get(
            attribute_label => 'member',
            attribute_value => $individual->id,
            subject_id => $self->id,
        );
        next unless $attribute;
        $attribute->delete;
        push @removed, $individual->id;
    }
    return 1 unless @removed; # Not removing anything is not an error, just return

    my $member_hash = $self->generate_hash_for_individuals($self->members);
    $self->member_hash($member_hash);
    return 1;
}

1;

