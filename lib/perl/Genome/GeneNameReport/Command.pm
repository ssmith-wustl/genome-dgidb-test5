package Genome::GeneNameReport::Command;

use strict;
use warnings;

use Genome;

class Genome::GeneNameReport::Command {
    is => 'Command::Tree',
};

sub help_brief {
    "work with gene-name-reports"
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
 genome gene-name-report ...
EOS
}

sub help_detail {
    return <<EOS
A collection of commands to interact with gene-names.
EOS
}

1;
