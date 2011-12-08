#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::Allpaths::Base;
use Test::More;

#test package
package Genome::Model::Tools::Allpaths::Test;
class Genome::Model::Tools::Allpaths::Test {
    is => 'Genome::Model::Tools::Allpaths::Base',
};

package main;
use_ok('Genome::Model::Tools::Allpaths') or die;

my $obj = Genome::Model::Tools::Allpaths::Test->create(version => 39099,
);

ok($obj, "Object was created");

done_testing();
