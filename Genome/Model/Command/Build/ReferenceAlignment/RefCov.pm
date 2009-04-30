package Genome::Model::Command::Build::ReferenceAlignment::RefCov;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::RefCov {
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
    return "-M 16000000 -R 'select[mem>16000] rusage[mem=16000]'";
}

sub execute {
    my $self = shift;

    my $build = $self->build;
    my $ref_cov_dir = $build->reference_coverage_directory;
    unless (Genome::Utility::FileSystem->create_directory($ref_cov_dir)) {
        $self->error_message('Failed to create ref_cov directory '. $ref_cov_dir .":  $!");
        return;
    }
    my $ref_cov = Genome::Model::Tools::RefCov::Parallel->execute(
                                                                  layers_file_path => $build->layers_file,
                                                                  genes_file_path => $build->genes_file,
                                                                  output_directory => $ref_cov_dir,
                                                              );
    unless ($ref_cov) {
        $self->error_message('Failed to run RefCov tool!');
        return;
    }
    return $self->verify_successful_completion;
}

sub verify_successful_completion {
    my $self = shift;
    my $build = $self->build;
    unless (-d $build->reference_coverage_directory .'/FROZEN') {
        $self->error_message('Failed to find frozen directory');
        return;
    }
    unless (-e $build->reference_coverage_directory .'/STATS.tsv') {
        $self->error_message('Failed to find stats file');
        return;
    }
    return 1;
}


1;
