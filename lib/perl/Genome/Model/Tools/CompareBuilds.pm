package Genome::Model::Tools::CompareBuilds;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::CompareBuilds {
    is => 'Command',
    is_abstract => 1,
    has => [
        first_build_id => {
            is => 'Number',
            doc => 'ID of first build to be compared',
        },
        first_build => {
            is => 'Genome::Model::Build',
            id_by => 'first_build_id',
        },
        second_build_id => {
            is => 'Number',
            doc => 'ID of second build to be compared',
        },
        second_build => {
            is => 'Genome::Model::Build',
            id_by => 'second_build_id',
        },
    ],
};

sub help_brief {
    return "Determines if builds from the same model produced the same output"; 
}

sub help_synopsis {
    return "Determines if builds from the same model produced the same output";
}

sub help_detail { 
    return <<EOS
Compares files from two given builds and determines if they are the same. Differences
are reported to STDOUT.
EOS
}

1;

