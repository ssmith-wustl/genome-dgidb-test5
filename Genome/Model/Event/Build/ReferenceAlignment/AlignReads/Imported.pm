package Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Imported;
use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Imported {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::AlignReads'],
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=4000]' -M 4000000 -n 4";
}

sub metrics_for_class {
    my $class = shift;
    my @metric_names = qw(total_read_count total_base_pair_count);
    return @metric_names;
}

sub total_read_count {
    return shift->get_metric_value('total_read_count');
}

sub _calculate_total_read_count {
    return shift->instrument_data->read_count;
}

sub total_base_pair_count {
    return shift->get_metric_value('total_base_count');
}

sub _calculate_total_base_pair_count {
    return shift->instrument_data->base_count;
}

1;

