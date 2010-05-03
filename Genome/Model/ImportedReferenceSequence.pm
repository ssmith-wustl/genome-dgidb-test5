package Genome::Model::ImportedReferenceSequence;
#:adukes see G:M:B:ImportedReferenceSequence, this needs to be expanded beyond use for ImportedAnnotation tasks only

use strict;
use warnings;

use Genome;

class Genome::Model::ImportedReferenceSequence {
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
    my @b = Genome::Model::Build::ImportedReferenceSequence->get('type_name' => 'imported reference sequence',
                                                                 'version' => $version,
                                                                 'model_id' => $self->genome_model_id);
    if (@b > 1) {
        die "Multiple builds for version $version for model " . $self->genome_model_id;
    }
    return $b[0];
}

1;
