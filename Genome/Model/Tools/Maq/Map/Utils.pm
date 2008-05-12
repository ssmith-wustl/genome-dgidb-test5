package Genome::Model::Tools::Maq::Map::Utils;

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

char* test_call_functionptr_with_string_param(void *p, char *s) {
    char* (*x)(char *s) = p;
    return (*x)(s);
}


END_C


1;
