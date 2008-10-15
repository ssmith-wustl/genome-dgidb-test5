package Genome::Model::Command::MetaGenomicComposition;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::MetaGenomicComposition {
    is => 'Genome::Model::Command',
    is_abstract => 1,
    #has => [],
};

sub help_brief {
    return "MGC";
}

sub help_detail {
    return <<"EOS"
EOS
}

1;

