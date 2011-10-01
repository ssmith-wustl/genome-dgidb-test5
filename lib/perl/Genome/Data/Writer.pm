package Genome::Data::Writer

use strict;
use warnings;

use base 'Genome::Data::ReaderWriter';

=head2
Usage: Creates a new object of type Genome::Data::Writer, which converts
       Genome::Data::Sequence objects into lines in a file.
Args : file => A path to the file to be written to
       format => The format of the provided file (eg, 'fasta')
=cut
sub create {
    my ($class, %params) = @_;
    $class = ref($class) || $class;
    my $self = $class->SUPER::create(%params);
    return $self;
}

sub access_mode {
    return 'w';
}

sub write_sequence {
    my $self = shift;
    my $adaptor = $self->data_adaptor();
    return $adaptor->write_sequence(@_);
}

1;

