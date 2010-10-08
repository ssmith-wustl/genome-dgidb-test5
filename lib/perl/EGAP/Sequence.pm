package EGAP::Sequence;

use strict;
use warnings;

use EGAP;
use Carp 'confess';

class EGAP::Sequence {
    type_name => 'sequence',
    schema_name => 'files',
    data_source => 'EGAP::DataSource::Sequences',
    id_by => [
        sequence_name   => { is => 'Text' },
    ],
    has => [
        file_path => { is => 'Path' },
        sequence_string => { is => 'Text' },
    ],
};

sub sub_sequence {
    my ($self, $start, $end) = @_;
    ($start, $end) = ($end, $start) if $start < $end;
    my $seq_string = $self->sequence_string;
    my $sub = substr($seq_string, $start, $end - $start + 1);
    return $sub;
}

1;
