
package Genome::Model::ImportedReferenceSequence;

use strict;
use warnings;

use Genome;

class Genome::Model::ImportedReferenceSequence{
    is => 'Genome::Model',
};

sub build_by_version {
    my $self = shift;
    my $version = shift;
    my @b = $self->builds("data_directory like" => "%/v${version}_%");
    if (@b > 1) {
        die "Multiple builds for version $version for model " . $self->model_id;
    }
    return $b[0];
}

1;

