#!/usr/bin/env perl

use Test::More tests => 27;
use above "URT"; 
use strict;
use warnings;


class TestClass1 {
    id_by => 'foo',
    has   => [
        foo   => { is => 'String' },
        value => { is => 'String' },
    ],
};

class TestClass2 {
    id_by => ['foo','bar'],
    has   => [
        foo   => { is => 'String' },
        bar   => { is => 'String' },
        value => { is => 'String' },
    ],
};


my $o;

$o = TestClass1->create(foo => 'aaaa', value => '1234');
ok($o, "Created TestClass1 object with explicit ID");
is($o->foo, 'aaaa', "Object's explicit ID has the correct value");
is($o->foo, $o->id, "Object's implicit ID property is equal to the explicit property's value");

$o = TestClass1->create(value => '2345');
ok($o, "Created another TestClass1 object with an autogenerated ID");
ok($o->foo, "The object has an autogenerated ID");
is($o->foo, $o->id, "The object's implicit ID property is equal to the explicit property's value");

my @error_messages = ();
TestClass1->message_callback('error', sub { push @error_messages, $_[0]->text });
$o = TestClass1->create(foo => 'aaaa', value => '123456');
ok(!$o, "Correctly couldn't create an object with a duplicated ID");
is(scalar(@error_messages), 1, 'Correctly trapped 1 error message');
like($error_messages[0], qr/An object of class TestClass1 already exists with id value 'aaaa'/,
   'The error message was correct');


$o = TestClass2->create(foo => 'aaaa', bar => 'bbbb', value => '1');
ok($o, "Created a TestClass2 object with both explicit ID properties");
is($o->foo, 'aaaa', "First explicit ID property has the right value");
is($o->bar, 'bbbb', "Second explicit ID property has the right value");
is($o->id, join("\t",'aaaa','bbbb'), "Implicit ID property has the right value");

@error_messages = ();
TestClass2->message_callback('error', sub { push @error_messages, $_[0]->text });

$o = TestClass2->create(foo => 'qqqq', value => 'blah');
ok(!$o, "Correctly couldn't create a multi-ID property object without specifying all the IDs");
is(scalar(@error_messages), 2, 'Correctly trapped 2 error messages');
like($error_messages[0], qr/Can't autogenerate ID property values for multiple ID property class TestClass2/,
   'The error message was correct');
like($error_messages[1], qr/No ID for new TestClass2/,
   'The error message was correct');


@error_messages = ();
$o = TestClass2->create(bar => 'wwww', value => 'blah');
ok(!$o, "Correctly couldn't create a multi-ID property object without specifying all the IDs, again");
is(scalar(@error_messages), 2, 'Correctly trapped 2 error messages');
like($error_messages[0], qr/Can't autogenerate ID property values for multiple ID property class TestClass2/,
   'The error message was correct');
like($error_messages[1], qr/No ID for new TestClass2/,
   'The error message was correct');



@error_messages = ();
$o = TestClass2->create(value => 'asdf');
ok(!$o, "Correctly couldn't create a multi-ID property object without specifying all the IDs, again");
is(scalar(@error_messages), 2, 'Correctly trapped 2 error messages');
like($error_messages[0], qr/Can't autogenerate ID property values for multiple ID property class TestClass2/,
   'The error message was correct');
like($error_messages[1], qr/No ID for new TestClass2/,
   'The error message was correct');



@error_messages = ();
$o = TestClass2->create(foo => 'aaaa', bar => 'bbbb', value => '2');
ok(!$o, "Correctly couldn't create another object with duplicated ID properites");
like($error_messages[0], qr/An object of class TestClass2 already exists with id value 'aaaa\tbbbb'/,
   'The error message was correct');

