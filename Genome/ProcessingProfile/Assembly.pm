package Genome::ProcessingProfile::Assembly;

use strict;
use warnings;

use Genome;

my @PARAMS = qw/
               read_filter
               read_filter_params
               read_trimmer
               read_trimmer_params
               assembler
               assembler_params
               sequencing_platform
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

