package Genome::Sample::Set::View::Detail::Html;

use strict;
use warnings;
require UR;

class Genome::Sample::Set::View::Detail::Html {
    is => 'UR::Object::View::Static::Html',
    has_constant => [
        toolkit     => { value => 'html' },
        perspective => { value => 'detail' }
    ]
};



1;
