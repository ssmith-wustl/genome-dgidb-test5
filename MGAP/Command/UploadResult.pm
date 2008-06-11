package MGAP::Command::UploadResult;

use strict;
use warnings;

use Workflow;

class MGAP::Command::UploadResult {
    is => ['MGAP::Command'],
    has => [
        bio_seq_features => { is => 'ARRAY', doc => 'array of Bio::Seq::Feature' },
    ],
};

operation MGAP::Command::UploadResult {
    input  => [ 'bio_seq_features' ],
    output => [ ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Write a set of fasta files for an assembly";
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
    $DB::single=1;


    1;
}
 
1;
