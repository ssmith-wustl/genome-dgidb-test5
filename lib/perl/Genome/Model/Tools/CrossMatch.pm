package Genome::Model::Tools::CrossMatch;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::CrossMatch {
    is => 'Command',
};

sub sub_command_sort_position { 14 }

sub help_brief {
    "Tools to run crossmatch or work with its output files.",
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

