package Genome::Model::Tools::Kmer::OccurrenceRatio;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Kmer::OccurrenceRatio {
    is => 'Genome::Model::Tools::Kmer',
    has => [
        output_type => {
            is => 'Text',
            default_value => 'nonunique unique relative',
        },
        index_name => {
            is => 'Text',
        },
        minimum_mer_size => {
            is => 'Integer',
            default_value => 1,
        },
        maximum_mer_size => {
            is => 'Integer',
            default_value => 32,
        },
    ],
};

sub execute {
    my $self = shift;

    my $gt_path = $self->genometools_path;
    my $options = '-output '. $self->output_type;
    if ($self->minimum_mer_size) {
        $options .= ' -minmersize '. $self->minimum_mer_size;
    }
    if ($self->maximum_mer_size) {
        $options .= ' -maxmersize '. $self->maximum_mer_size;
    }
    my $cmd = $gt_path .' tallymer occratio '. $options .' -esa '. $self->index_name;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
    );
    return 1;
}
