package Genome::Model::Tools::Readcount;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Readcount {
    is  => 'Command',
    is_abstract => 1,
    doc => "Tools to get readcount information",
};

sub help_synopsis {
    "gmt readcount ...";
}

sub help_detail {                           
    "used to get readcount information";
}

1;

