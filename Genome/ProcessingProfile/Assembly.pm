package Genome::ProcessingProfile::Assembly;

use strict;
use warnings;

use above "Genome";

my @PARAMS = qw/
               read_filter
               read_trimmer
               assembler
              /;

class Genome::ProcessingProfile::Assembly{
    is => 'Genome::ProcessingProfile',
    has => [
            ( map { $_ => {
                           via => 'params',
                           to => 'value',
                           where => [name => $_],
                           is_mutable => 1
                       },
                   } @PARAMS
         ),
        ],
};

sub params_for_class {
    my $class = shift;
    return @PARAMS;
}



1;

