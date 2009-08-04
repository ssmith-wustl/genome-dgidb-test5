
package Genome::Model::ImportedReferenceSequence;

use strict;
use warnings;

use Genome;

class Genome::Model::ImportedReferenceSequence{
    is => 'Genome::Model',
    has => [
        species_name => {
            via => 'subject',
            to => 'species_name',
        },
    ]
};

sub build_by_version {
    my $self = shift;
    my $version = shift;
    my @b = $self->builds("data_directory like" => "%/v${version}-%");
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

sub species{
    my $self = shift;
    return $self->subject_name;
}

1;

