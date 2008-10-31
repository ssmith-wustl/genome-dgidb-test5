#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
}

use strict;
use warnings;
use above "Genome";
use Test::More tests => 18;

require_ok('Genome::ProcessingProfile');

ok(do {
    my $trapped_warning = 0;
    local $SIG{__WARN__} = sub {
        if ($_[0] =~ /params_for_class not implemented/) {
            $trapped_warning=1;
        }
    };

    Genome::ProcessingProfile->params_for_class;

    $trapped_warning;
},'trigger warning for params_for_class');

## nothing else tests this, just do it explicitly
ok(!defined Genome::ProcessingProfile->_resolve_type_name_for_subclass_name('Foo::Bar::Baz::Fail::Regex'),'_resolve_type_for_subclass_name returns undef for bad subclass name');
ok(!Genome::ProcessingProfile->_resolve_subclass_name(Genome->get),'returns false on attempt to resolve classes that dont inherit from me');

## tests _resolve_subclass_name
my @pp;
ok(@pp = Genome::ProcessingProfile->get(),'get all processing profiles');

UR::Object::Type->define(
    class_name => 'Genome::ProcessingProfile::AbstractBaseTest',
    english_name => 'genome processing_profile abstract_base_test',
    extends => ['Genome::ProcessingProfile'],
    properties => [
        colour => {
            via => 'params',
            to => 'value',
            where => [ name => 'colour' ],
            is_optional => 1,
            is_mutable => 1
        },
        size => {
            is_calculated => q{
               rand(10) > 5 ? 'big' : 'small' 
            }
        },
        shape => { is => 'String' },
        empty_string => { is => 'String', default_value => '' },
        be_a_ref => { is => 'ARRAY' } 
   ] 
);

sub Genome::ProcessingProfile::AbstractBaseTest::params_for_class {
    return qw/colour size shape empty_string be_a_ref method_you_will_hate/;
}

sub Genome::ProcessingProfile::AbstractBaseTest::method_you_will_hate {
    return if wantarray;
    return 0;
}

my $pp;
ok($pp = Genome::ProcessingProfile->create(name => 'tpp1', type_name => 'abstract base test'),'create with type_name');

my $old_cb = UR::ModuleBase->message_callback('error');
UR::ModuleBase->message_callback('error', sub { });
ok(!defined Genome::ProcessingProfile->create(name => 'tpp1', type_name => 'abstract base test', id => $pp->id),'create with existing id returned undef');
UR::ModuleBase->message_callback('error', $old_cb);

ok($pp->colour('blue'),'set colour to blue');
ok(Genome::ProcessingProfile::Param->create(processing_profile=>$pp,name=>'colour',value=>'red'),'set colour to also be red');

TODO: {
    local $TODO = 'pretty_print_text is broken with multiple params of the same name';

    ok(eval { $pp->pretty_print_text },'pretty_print_text on object');
}

ok($pp->delete,'delete processing profile');

my $pp2;
ok($pp2 = Genome::ProcessingProfile::AbstractBaseTest->create(name => 'tpp2'),'create with package'); 
ok($pp2->be_a_ref([]),'set be_a_ref to empty array reference');
ok($pp2->colour('blue'),'set colour to blue');
ok($pp2->pretty_print_text,'pretty_print_text on object');
ok($pp2->delete,'delete processing profile');

my $pp3;
ok($pp3 = Genome::ProcessingProfile::AbstractBaseTest->create,'create with no args');
ok($pp3->delete,'delete processing profie');


