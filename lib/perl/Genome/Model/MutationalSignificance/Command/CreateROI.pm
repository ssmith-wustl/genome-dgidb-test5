package Genome::Model::MutationalSignificance::Command::CreateROI;

use strict;
use warnings;

use Genome;

my $DEFAULT_LSF_RESOURCE = "-R 'select[model!=Opteron250 && type==LINUX64 && mem>64000 && tmp>150000] span[hosts=1] rusage[tmp=150000, mem=64000]' -M 64000000 -n 4";

class Genome::Model::MutationalSignificance::Command::CreateROI {
    is => ['Command::V2'],
    has_input => [
        build_id => {},
    ],
    has_output => [
        roi_path => {
            is => 'String',
        },
    ],
    has_param => [
        lsf_resource => { default_value => $DEFAULT_LSF_RESOURCE },
    ],
};

sub execute {
    my $self = shift;

    $self->roi_path("a_roi_path");
    $self->status_message('Created ROI file');
    return 1;
}

1;
