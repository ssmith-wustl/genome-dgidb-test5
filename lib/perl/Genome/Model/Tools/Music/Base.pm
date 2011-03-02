package Genome::Model::Tools::Music::Base;

use strict;
use warnings;
use Genome;

our $VERSION = '0.01';

class Genome::Model::Tools::Music::Base {
    is => ['Command::V2'],
    is_abstract => 1,
    has_optional => [
         version => {
             is    => 'String',
             doc   => 'version of Music application to use',
         },
    ],
    attributes_have => [
        file_format => {
            is => 'Text',
            is_optional => 1,
        }
    ],
    doc => "cancer mutation analysis"
};

sub help_detail { "" }

1;

