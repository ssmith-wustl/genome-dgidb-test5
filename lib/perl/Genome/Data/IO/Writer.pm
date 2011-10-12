package Genome::Data::Writer;

use strict;
use warnings;

use Genome::Data::IO;
use base 'Genome::Data::IO';

sub access_mode {
    return 'w';
}

sub write {
    my $self = shift;
    my $adaptor = $self->data_adaptor();
    return $adaptor->write_to_file(@_);
}

1;

