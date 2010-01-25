package Genome::Model::Tools::Blat;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Blat {
    is => 'Command',
};

sub sub_command_sort_position { 14 }

sub help_brief {
    "Tools to run blat or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt blat ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

1;

