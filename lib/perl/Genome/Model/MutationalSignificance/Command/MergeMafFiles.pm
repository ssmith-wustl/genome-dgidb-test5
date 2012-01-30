package Genome::Model::MutationalSignificance::Command::MergeMafFiles;

use strict;
use warnings;

use Genome;
use Data::Dumper;

my $DEFAULT_LSF_RESOURCE = "-R 'select[model!=Opteron250 && type==LINUX64 && mem>64000 && tmp>150000] span[hosts=1] rusage[tmp=150000, mem=64000]' -M 64000000 -n 4";

class Genome::Model::MutationalSignificance::Command::MergeMafFiles {
    is => ['Command::V2'],
    has_input => [
        array_of_model_outputs => {},
    ],
    has_output => [
        maf_path => {
            is => 'String'},
    ],
    has_param => [
        lsf_resource => { default_value => $DEFAULT_LSF_RESOURCE },
    ],
};

sub execute {
    my $self = shift;

    my $count = 0;
    my $model_outputs = $self->array_of_model_outputs;
    foreach my $output (@$model_outputs) {
        $count++;
    }

    my $dumper_string = Dumper($self->array_of_model_outputs);

    $self->maf_path("a_merged_maf_file");

    my $status = "Merged $count MAF files. Dump: $dumper_string";
    $self->status_message($status);
    return 1;
}

1;
