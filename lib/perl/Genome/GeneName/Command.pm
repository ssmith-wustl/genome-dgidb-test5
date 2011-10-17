package Genome::GeneName::Command;

use strict;
use warnings;

use Genome;

class Genome::GeneName::Command {
    is => 'Command::Tree',
};

sub help_brief {
    "work with gene-names"
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
 genome gene-name ...
EOS
}

sub help_detail {
    return <<EOS
A collection of commands to interact with gene-names.
EOS
}

1;
