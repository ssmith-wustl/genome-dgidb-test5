#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
}

use strict;
use warnings;
use above "Genome";
use Test::More tests => 15;

require_ok('Genome::ProcessingProfile');
ok(my @all_pp = Genome::ProcessingProfile->get, 'Got all processing profiles');


#< EXPLICITLY TEST SOME PRIVATE METHODS #>
is(Genome::ProcessingProfile->_resolve_type_name_for_class, undef, '_resolve_type_for_subclass_name is undef for base PP');
is(Genome::ProcessingProfile::Test->_resolve_type_name_for_class, 'test', '_resolve_type_for_subclass_name is test for PP::Test');
ok(do {
    my $trapped_warning = 0;
    local $SIG{__WARN__} = sub {
        if ($_[0] =~ /params_for_class not implemented/) {
            $trapped_warning=1;
        }
    };

    Genome::ProcessingProfile->params_for_class; # should be private

    $trapped_warning;
},'trigger warning for params_for_class');

#< GOOD >#
my $pp = Genome::ProcessingProfile::Test->create(
    name => 'tpp1',
    colour => 'black',
    shape => 'square',
);
ok($pp, 'Create thru subclass');
is($pp->type_name, 'test', 'Checking type_name (test)');
is($pp->colour, 'black', 'Checking colour (black)');
is($pp->shape, 'square', 'Checking shape (square)');
$pp->colour('blue');
is($pp->colour, 'blue', 'Set colour to blue');

my $pp2 = Genome::ProcessingProfile->create(
    name => 'tpp1', 
    type_name => 'test',
    colour => 'grey',
);
ok($pp2,'Create with type_name given');
ok($pp2->delete, 'delete processing profile');

#< FAILS >#
my $no_name_pp = Genome::ProcessingProfile::Test->create(colour => 'grey', shape => 'round');
ok(!$no_name_pp,'Failed as expected: create with no name');

undef $@;
eval { # this should die
    Genome::ProcessingProfile->create(name => 'no type name');
};
ok($@, 'Failed as expected: create with no way to resolve type name');
print "$@\n";

print "$@\n";
undef $@;
eval { # this should die
    Genome::ProcessingProfile::Test->create(name => 'no type name', type_name => 'not test');
};
ok($@, 'Failed as expected: create where subclass does not match type_name');
print "$@\n";

exit;

#$HeadURL$
#$Id$
