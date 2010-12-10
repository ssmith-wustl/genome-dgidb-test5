package Genome::Model::Tools::Music;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use File::Temp;

my $DEFAULT_VERSION = '1.1';

class Genome::Model::Tools::Music {
    is => ['Command'],
    has_optional => [
         version => {
             is    => 'String',
             doc   => 'version of Music application to use',
         },
    ],
};

sub help_brief {
    "Suite of tools for mutation analysis"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS

EOS
}



1;

