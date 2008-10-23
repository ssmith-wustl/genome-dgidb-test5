package Genome::Model::Tools::WuBlast::Xdformat;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::WuBlast::Xdformat {
    is => 'Command',
};

sub help_brief {
    "Tools to run xdformat for creating, appending, and verifying xdb databases",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt wu-blast xdformat...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

1;

