package Genome::Model::Build::ImportedVariations;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ImportedVariations {
    is => 'Genome::Model::Build',
    has => [
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

sub variation_iterator{
    my $self = shift;
    my %p = @_;

    my $chrom_name = delete $p{chrom_name};

    if ($chrom_name){
            return Genome::Variation->create_iterator(where => [data_directory => $self->variation_data_directory, chrom_name => $chrom_name, %p]);
    }else{
        $self->error_message("No chromosome name provided to create variation iterator");
    }
}

1;
