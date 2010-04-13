package Genome::View::SearchResult::Html;

use strict;
use warnings;

class Genome::View::SearchResult::Html {
    is => 'UR::Object::View::Default::Html',
    is_abstract => 1,
    has_constant => [
        perspective => 'search-result',
    ],
    doc => 'Concrete classes that want to be able to transform their SearchResult::Xml views to html should inherit from this class.'
};

1;
