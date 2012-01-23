package Genome::Model::MutationalSignificance::Command::PlayMusic;

use strict;
use warnings;

use Genome;

my $DEFAULT_LSF_RESOURCE = "-R 'select[model!=Opteron250 && type==LINUX64 && mem>64000 && tmp>150000] span[hosts=1] rusage[tmp=150000, mem=64000]' -M 64000000 -n 4";

class Genome::Model::MutationalSignificance::Command::PlayMusic {
    is => ['Command::V2'],
    has_input => [
        maf_path => {
            is => 'String'
        },
        roi_path => {
            is => 'String'
        },
        clinical_data_file => {
            is => 'String'
        },
        bam_list => {
            is => 'String',
        },
    ],
    has_output => [
        smg_result => {
            is => 'String',
        },
        pathscan_result => {
            is => 'String',
        },
        mrt_result => {
            is => 'String',
        },
        pfam_result => {
            is => 'String',
        },
        proximity_result => {
            is => 'String',
        },
        cosmic_result => {
            is => 'String',
        },
        cct_result => {
            is => 'String',
        },
    ],
    has_param => [
        lsf_resource => { default_value => $DEFAULT_LSF_RESOURCE },
    ],
};

sub execute {
    my $self = shift;

    $self->status_message($self->maf_path);
    $self->status_message($self->roi_path);
    $self->status_message($self->clinical_data_file);
    $self->status_message($self->bam_list);
    $self->cct_result("a_cct_result");
    $self->cosmic_result("a_cosmic_result");
    $self->proximity_result("a_proximity_result");
    $self->pfam_result("a_pfam_result");
    $self->smg_result("a_smg_result");
    $self->mrt_result("a_mrt_result");
    $self->pathscan_result("a_pathscan_result");
    $self->status_message('Played MuSiC');
    return 1;
}

1;
