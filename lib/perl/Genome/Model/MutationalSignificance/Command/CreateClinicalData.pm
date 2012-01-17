package Genome::Model::MutationalSignificance::Command::CreateClinicalData;

use strict;
use warnings;

use Genome;

my $DEFAULT_LSF_RESOURCE = "-R 'select[model!=Opteron250 && type==LINUX64 && mem>64000 && tmp>150000] span[hosts=1] rusage[tmp=150000, mem=64000]' -M 64000000 -n 4";

class Genome::Model::MutationalSignificance::Command::CreateClinicalData {
    is => ['Command::V2'],
    has_input => [
        build_id => {},
    ],
    has_output => [
        clinical_data_file => {
            is => 'String',
        },
    ],
    has_param => [
        lsf_resource => { default_value => $DEFAULT_LSF_RESOURCE },
    ],
};

sub execute {
    my $self = shift;

    $self->clinical_data_file("a_clinical_data_file");
    $self->status_message('Created clinical data file');
    return 1;
}

1;
