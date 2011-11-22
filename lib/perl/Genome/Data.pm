package Genome::Data;

use strict;
use warnings;

sub create {
    die ("Genome::Data::create must be implemented by the child class");
}
# This class exists just so you can generically refer to sequences, variants
# etc under Genome/Data*. It also makes it possible for DataSets to be composed
# of Data, which seems more appropriate than having DataSets composed of a
# collection of objects of varying types all under Genome/Data. 

1;

