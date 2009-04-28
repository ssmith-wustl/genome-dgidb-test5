package Genome::Model::Command::Build::ReferenceAlignment::Layers;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::Layers {
    is => ['Genome::Model::Event'],
    has => [
        ],
};

sub help_brief {
    "Use maq to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads postprocess-alignments merge-alignments maq --model-id 5 --ref-seq-id all_sequences
EOS
}

sub help_detail {
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub bsub_rusage {
    return "-M 16000000 -R 'select[model!=Opteron250 && type==LINUX64 && mem>16000] rusage[mem=16000]'";
}

sub execute {
    my $self = shift;

    my $model = $self->model;
    my $build = $self->build;
    unless (Genome::Utility::FileSystem->create_directory($build->reference_coverage_directory)) {
        $self->error_message('Failed to create reference_coverage directory '. $build->reference_coverage_directory .":  $!");
        return;
    }
    my $layers = Genome::Model::Tools::Maq::MapToLayers->execute(
                                                                 use_version => $model->read_aligner_version,
                                                                 map_file => $build->whole_map_file,
                                                                 layers_file => $build->layers_file,
                                                                 randomize => 1,
                                                             );
    unless ($layers) {
        $self->error_message('Failed to run MapToLayers tool!');
        return;
    }
    return 1;
}



1;
