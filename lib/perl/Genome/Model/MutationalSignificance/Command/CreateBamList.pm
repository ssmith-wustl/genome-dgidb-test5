package Genome::Model::MutationalSignificance::Command::CreateBamList;

use strict;
use warnings;

use Genome;

my $DEFAULT_LSF_RESOURCE = "-R 'select[model!=Opteron250 && type==LINUX64 && mem>64000 && tmp>150000] span[hosts=1] rusage[tmp=150000, mem=64000]' -M 64000000 -n 4";

class Genome::Model::MutationalSignificance::Command::CreateBamList {
    is => ['Command::V2'],
    has_input => [
        build_id => {},
    ],
    has_output => [
        bam_list => {
            is => 'String',},
    ],
    has_param => [
        lsf_resource => { default_value => $DEFAULT_LSF_RESOURCE },
    ],
};

sub execute {
    my $self = shift;

    $self->bam_list("a_bam_list");
    $self->status_message('Created BAM list');
    return 1;
}

1;
