package Genome::Model::Tools::Maq::Map::Utils;

use strict;
use warnings;
use Genome::Inline;

use Inline 'C' => 'Config' => (DIRECTORY => Genome::Inline::DIRECTORY());
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
