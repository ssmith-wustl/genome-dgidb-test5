package Genome::Model::Command::Build::ImportedVariations;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ImportedVariations {
    is => 'Genome::Model::Command::Build',
    has => [
        variation_data_directory => {
            is => 'Path',
            doc => 'path to imported_annotation folder, not needed if this is a composite annotation model, not needed for composite annotation models(combined-annotation)',
        },
        version => {
            is => 'String',
            doc => 'Version number of the annotation db, for ensembl, genbank, and esembl/genbank combined this take the form of <ensembl_version_number>_<human_build_version><Ensembl_iteration_letter> ie. 53_36n',
        },
    ],
    doc => "custom launcher for imported variation builds"
};

sub sub_command_sort_position { 98 }

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given imported annotation db
EOS
}

sub create{
    #TODO remove build if conditions aren't met after create.  Ask jwalker for an example of this
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self){
        $self->error_message("Failed to create instance of class $class with params @_");
        die;
    }
    
    my $build = $self->build;
    $build->version($self->version);
    $build->variation_data_directory($self->variation_data_directory);

    return $self;
}

1;
