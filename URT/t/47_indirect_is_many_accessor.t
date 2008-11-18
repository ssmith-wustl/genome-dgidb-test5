use above 'UR';

use Test::More;
plan tests => 11;

UR::Object::Type->define(
    class_name => 'URT::Param',
    id_by => [
        thing_id => { is => 'Number' },
        name => { is => 'String' },
        value => { is => 'String'},
    ],
    has => [
        thing => { is => 'URT::Thing', id_by => 'thing_id' },
    ],
);
UR::Object::Type->define(
    class_name => 'URT::Thing',
    id_by => [
        'thing_id' => { is => 'Number' },
    ],
    has => [
        params => { is => 'URT::Param', reverse_id_by => 'thing', is_many => 1 },
        # Actually, either of these property definitions will work
        interesting_param_values => { via => 'params', to => 'value', is_many => 1, is_mutable => 1,
                                      where => [ name => 'interesting'] },

        #interesting_params => { is => 'URT::Param', reverse_id_by => 'thing', is_many => 1,
        #                        where => [name => 'interesting']},
        #interesting_param_values => { via => 'interesting_params', to => 'value', is_many => 1, is_mutable => 1 },
    ],
);


# make a non-interesting one ahead of time
URT::Param->create(thing_id => 2, name => 'uninteresting', value => '123');

my $o = URT::Thing->create(thing_id => 2, interesting_param_values => ['abc','def']);
ok($o, 'Created another Thing');
my @params = $o->params();;
is(scalar(@params), 3, 'And it has 3 attached params');
isa_ok($params[0], 'URT::Param');
isa_ok($params[1], 'URT::Param');
isa_ok($params[2], 'URT::Param');

@params = sort { $a->value cmp $b->value } @params;
is($params[0]->name, 'uninteresting', "param 1's name is uninteresting");
is($params[1]->name, 'interesting', "param 2's name is interesting");
is($params[2]->name, 'interesting', "param 3's name is interesting");

is($params[0]->value, '123', "param 1's value is correct");
is($params[1]->value, 'abc', "param 2's value is correct");
is($params[2]->value, 'def', "param 3's value is correct");

