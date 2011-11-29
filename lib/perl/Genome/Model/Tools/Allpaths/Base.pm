package Genome::Model::Tools::Allpaths::Base;

use strict;
use warnings;

use Genome;

my %versions = (
    39099 => { },
);

class Genome::Model::Tools::Allpaths::Base {
    is => 'Command::V2',
    is_abstract => 1,
    has => [
	    version => {
            is => 'Text',
            doc => 'Version of ALLPATHS to use',
            valid_values => [ sort keys %versions ],
        },
    ],
};

sub allpaths_directory {
    return '/gsc/pkg/bio/allpaths';
}

sub allpaths_version_directory {
    my ($self, $version) = @_;
}

sub RunAllPathsLG_path {
}

1;

