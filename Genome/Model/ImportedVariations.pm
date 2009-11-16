package Genome::Model::ImportedVariations;
#:adukes not used, meant for dbsnp 130, currently handled by something else.  Dump this until the other solution needs to be abstracted

use strict;
use warnings;

use Genome;

class Genome::Model::ImportedVariations{
    is => 'Genome::Model',
    has =>[
            version => { 
            via => 'inputs', 
            to => 'value_id', 
            where => [ name => 'version' ], 
            is_mutable => 1 
        },
        variation_data_directory => {
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'variation_data_directory' ],
            is_mutable => 1 
        },
    ],
};


sub build_by_version {
    my $self = shift;
    my $version = shift;
    my @builds =  grep { $_->version eq $version} $self->builds;
    if (@builds > 1) {
        my $versions_string = join("\n", map { "model_id ".$_->model_id." build_id ".$_->build_id." version ".$_->version } @builds);
        $self->error_message("Multiple builds for version $version for model " . $self->genome_model_id.", ".$self->name."\n".$versions_string."\n");
        die;
    }
    return $builds[0];
}

sub variation_data_directory{
    my $self = shift;
    my $build = $self->last_complete_build;
    return $build->variation_data_directory;
}

1;

