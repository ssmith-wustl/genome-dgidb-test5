package Genome::Data::Reader;

use strict;
use warnings;

use Genome::Data::ReaderWriter;
use base 'Genome::Data::ReaderWriter';

=head2
Usage: Creates a new object of type Genome::Data::Reader, which is used
       to parse file and return objects representing the data.
Args : file => A path to the file to be parsed
       format => The format of the provided file (eg, 'fasta')
=cut
sub create {
    my ($class, %params) = @_;
    $class = ref($class) || $class;
    return $class->SUPER::create(%params);
}

sub access_mode {
    return 'r';
}

sub next {
    my $self = shift;
    my $adaptor = $self->data_adaptor();
    return $adaptor->parse_next_sequence(@_);
}

1;

