
package Genome::ProcessingProfile::ImportedVariants;

use strict;
use warnings;

use Genome;

my @PARAMS = qw/
                instrument_data
              /;

class Genome::ProcessingProfile::ImportedVariants{
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
