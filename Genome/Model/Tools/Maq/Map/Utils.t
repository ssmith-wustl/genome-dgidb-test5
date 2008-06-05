#!/usr/bin/env perl

package Genome::Model::Tools::Maq::Map::Utils::Test;

use above "Genome";                         # >above< ensures YOUR copy is used during development
use Test::More tests => 5;

class Genome::Model::Tools::Maq::Map::Utils::Test {
    is => 'Command',
    has => [
        some_input  => { is => 'String', is_optional => 1, default_value => '0.6.3', doc => "Version of maq to use, if not the newest." },
        some_output => { is => 'String', is_optional => 1 },
    ],
};

run_tests();

sub run_tests {
    my $command = __PACKAGE__->create(some_input => "hello");
    ok($command->execute(), "executed");
    is($command->some_output, "c: hello");

    $command = __PACKAGE__->create(some_input => "goodbye");
    ok($command->execute(), "executed");
    is($command->some_output, "c: goodbye");
    
    $command = __PACKAGE__->execute(some_input => "adios");
    is($command->some_output, "c: adios");

    1;
}

sub execute {
    $DB::single = 1;
    my $self = shift;
    my $fptr = Genome::Model::Tools::Maq::Map::Utils::Test::CSubs::test_ssmith_fptr();
    print "got address: $fptr\n";
    my $s = { x => $self->some_input };
    #utf8::upgrade($s);
    my $result = Genome::Model::Tools::Maq::Map::Utils::test_call_functionptr_with_string_param($fptr, $s->{x});
    print "called function got return: $result\n";
    $self->some_output($result);
    return $result;
}

#
# The C extensions go into a sub-namespace so Inline doesn't have odd errors with the autoloader.
#

package Genome::Model::Tools::Maq::Map::Utils::Test::CSubs;

use Genome::Model::Tools::Maq::Map::Utils;

use strict;
use warnings;

our $inline_dir;
BEGIN {
    my $uname=`uname -a`;
    if ($uname =~ /ia64/) {
        $inline_dir="$ENV{HOME}/_InlineItanium";
    }elsif($uname =~ /x86_64/ ) {
        $inline_dir="$ENV{HOME}/_Inline64";
    }else {
       $inline_dir = "$ENV{HOME}/_Inline32";
    }
     mkdir $inline_dir;
};
use Inline 'C' => 'Config' => (DIRECTORY => $inline_dir );
use Inline 'C' => <<'END_C';

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char* test_ssmith (char* s) {
    static char r[100];
    sprintf(&r, "c: %s", s);
    return r;
}

void* test_ssmith_fptr() {
    return &test_ssmith;
}


END_C


1;
