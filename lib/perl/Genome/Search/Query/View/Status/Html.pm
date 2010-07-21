package Genome::Search::Query::View::Status::Html;

use strict;
use warnings;
use Genome;

class Genome::Search::Query::View::Status::Html {
    is           => 'UR::Object::View::Default::Html',
    has_constant => [ perspective => { value => 'status', }, ],
};

## this is a cheap hack because i need to tell the search engine itself
## to give html, not transform it
sub _generate_content {
    my $self = shift;

    $self->subject->{format} = 'html';
    my $result = $self->SUPER::_generate_content(@_);
    delete $self->subject->{format};

    return $result;
}

