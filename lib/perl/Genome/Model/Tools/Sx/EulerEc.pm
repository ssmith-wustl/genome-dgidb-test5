package Genome::Model::Tools::Sx::EulerEc;

use strict;
use warnings;

use Genome;
use Data::Dumper 'Dumper';

class Genome::Model::Tools::Sx::EulerEc {
    is => 'Command',
    has => [],
};

sub help_brief {
    'Tool to run EulerEc.pl',
}

sub help_detail {
    return <<"EOS"
EOS
}

sub execute {
    my $self = shift;

    $self->status_message( 'Initial stub in .. will make it do stuff later' );

    return 1;
}

1;
