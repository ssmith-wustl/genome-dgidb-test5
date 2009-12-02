
package Genome::ProcessingProfile::ImportedVariants;

#:eclark 11/16/2009 Code review.

# I'm a little unclear what this is trying to do.  Similar processing profiles without parameters don't implement params_for_class, they leave it with the default undefined return value.

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedVariants{
    is => 'Genome::ProcessingProfile::Staged',
};
