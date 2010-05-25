
package Genome::Search::Query;

use strict;
use warnings;

class Genome::Search::Query {
    is => 'UR::Value',
    id_by => [
        query => { is => 'Text' },
        page => { is => 'Number' }
    ],
};

sub get {
    my $class = shift;
    if (@_ > 1 && @_ % 2 == 0) {
        my %args = (@_);
        $args{page} = 1 unless exists $args{page};
        @_ = %args;
    }

    return $class->SUPER::get(@_);
}

