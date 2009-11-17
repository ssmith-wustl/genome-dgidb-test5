package Genome::AmpliconAssembly::Report;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::AmpliconAssembly::Report {
    is => 'Genome::Report::Generator',
    has => [
    amplicon_assemblies => {
        is => 'ARRAY',
        doc => 'Amplicon assemblies to generate stats.',
    },
    ],
};

#:jpeck I am not in love with Report/Generator design.  It seems like there is some unnecessary indirection. 
#< Generator >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->amplicon_assemblies ) {
        $self->error_message('No amplicon assemblies given to generate stats');
        $self->delete;
        return;
    }

    return $self;
}

1;

#$HeadURL$
#$Id$
