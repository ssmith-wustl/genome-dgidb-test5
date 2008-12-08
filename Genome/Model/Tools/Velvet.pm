package Genome::Model::Tools::Velvet;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Velvet {
    is => 'Command',
};

sub sub_command_sort_position { 14 }

sub help_brief {
    "Tools to run velvet, a short reads assembler, and work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt velvet ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

1;

