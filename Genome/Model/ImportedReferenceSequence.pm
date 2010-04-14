package Genome::Model::ImportedReferenceSequence;
#:adukes see G:M:B:ImportedReferenceSequence, this needs to be expanded beyond use for ImportedAnnotation tasks only

use strict;
use warnings;

use Genome;

class Genome::Model::ImportedReferenceSequence{
    is => 'Genome::Model',
    has => [
        fasta_file => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'fasta_file', value_class_name => 'UR::Value' ],
            is_mutable => 1,
            is_many => 0,
            doc => 'fully qualified fasta filename (eg /foo/bar/input.fasta)'
        },
    ],
    has_optional => [
        version => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'version', value_class_name => 'UR::Value' ],
            is_many => 0,
            is_mutable => 1 
        },
        prefix => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'prefix', value_class_name => 'UR::Value' ],
            is_many => 0,
            is_mutable => 1
        }
    ]
};

sub build_by_version {
    my $self = shift;
    my $version = shift;
    my @b = $self->builds("version" => "$version");
    if (@b > 1) {
        die "Multiple builds for version $version for model " . $self->model_id;
    }
    return $b[0];
}

sub sequence
{
    my $self = shift;
    my $build = $self->last_complete_build();
    return $build->sequence(@_);
}

sub get_bases_file
{
    my $self = shift;
    my $build = $self->last_complete_build();
    return $build->get_bases_file(@_);
}

sub species
{
    my $self = shift;
    return $self->subject_name;
}

1;

