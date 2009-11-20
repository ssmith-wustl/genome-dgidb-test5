package Genome::Model::Command::Build::ReferenceAlignment::Layers;

#REVIEW fdu 11/19/2009
#This module once was implemented as one step of stage reference
#coverage. But jwalker removed this from that stage on 08/05/2009 
#(see svn revision r49591). Remove soon.

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
    unless (-s $build->layers_file) {
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
    }
    return $self->verify_successful_completion;
}

sub verify_successful_completion {
    my $self = shift;

    my $build = $self->build;

    unless (-d $build->reference_coverage_directory) {
        $self->error_message('Failed to create reference coverage directory '. $build->reference_coverage_directory);
        return;
    }
    unless (-s $build->layers_file > -s $build->whole_map_file) {
        $self->error_message('The size of the layers file '. $build->layers_file
                             .' is smaller than the compressed map file '. $build->whole_map_file);
        return;
    }
    return 1;
}



1;
