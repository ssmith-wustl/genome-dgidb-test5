
package Genome::Model::3730;

use strict;
use warnings;

use above "Genome";

class Genome::Model::3730{
    is => 'Genome::Model::ImportedVariants',
};

sub _base_directory {
    my $self = shift;

    return '/gscmnt/834/info/medseq/imported_variants_data/3730/';
}


# Returns the full path to the file where the microarray data should be
# Should work for all submodules
sub _data_file {
    my $self = shift;

    my $model_dir = $self->_model_directory;
    my $model_name = $self->name;
    my $type = $self->_type;

    # Replace spaces with underscores for a valid file name
    $model_name =~ s/ /_/g;
    
    my $file_location = "$model_dir/$type.data";

   return $file_location; 
}

sub _process_new_data{
    my $self=shift;
    return 1;
}

1;

