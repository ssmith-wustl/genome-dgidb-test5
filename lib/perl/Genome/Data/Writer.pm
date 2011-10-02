package Genome::Data::Writer;

use strict;
use warnings;

use Genome::Data::ReaderWriter;
use base 'Genome::Data::ReaderWriter';

sub access_mode {
    return 'w';
}

sub write_to_file {
    my $self = shift;
    my $adaptor = $self->data_adaptor();
    return $adaptor->write_to_file(@_);
}

1;

