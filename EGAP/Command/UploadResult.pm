package EGAP::Command::UploadResult;

use strict;
use warnings;

use Workflow;

class EGAP::Command::UploadResult {
    is  => ['EGAP::Command'],
    has => [
        seq_set_id => {
            is  => 'SCALAR',
            doc => 'identifies a whole assembly'
        },
        bio_seq_features => {
            is  => 'ARRAY',
            doc => 'array of Bio::Seq::Feature'
        },
    ],
};

operation_io EGAP::Command::UploadResult {
    input  => [ 'bio_seq_features', 'seq_set_id'],
    output => [ 'result' ],
};

sub sub_command_sort_position {10}

sub help_brief {
    "Store input gene predictions in the EGAP schema";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {

    my $self = shift;

    return 1;

}

1;
