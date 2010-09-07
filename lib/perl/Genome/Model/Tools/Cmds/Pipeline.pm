package Genome::Model::Tools::Cmds::Pipeline;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Cmds::Pipeline {
    is => ['Command'],
};

sub help_brief {
    "Tools to work with CMDS pipelines"
}

sub help_detail {
    return <<EOS
Tools to work with CMDS pipelines
EOS
}

1;
