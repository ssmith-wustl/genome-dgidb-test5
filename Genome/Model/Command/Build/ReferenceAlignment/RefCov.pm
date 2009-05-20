package Genome::Model::Command::Build::ReferenceAlignment::RefCov;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::RefCov {
    is => ['Genome::Model::Event'],
    has => [ ],
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
    my @instrument_data = $build->instrument_data;
    unless (Genome::Model::Tools::RefCov::Snapshot->execute(
                                                            snapshots => scalar(@instrument_data),
                                                            layers_file_path => $build->layers_file,
                                                            genes_file_path => $build->genes_file,
                                                            output_directory => $ref_cov_dir,
                                                        )) {
        $self->error_message('Failed to run RefCov tool!');
        return;
    }
    unless (opendir(DIR,$ref_cov_dir)) {
        $self->error_message('Failed to open ref-cov directory '. $ref_cov_dir .":  $!");
        return;
    }
    my @snapshots = grep { -d  } map { $ref_cov_dir .'/'. $_ } grep { $_ !~ /^composed/ } grep { $_ !~ /^\./ } readdir(DIR);
    closedir(DIR);

    unless (@snapshots) {
        $self->error_message('Failed to find snapshots in ref-cov directory '. $ref_cov_dir);
        return;
    }

    my $composed_dir = $ref_cov_dir .'/composed';
    unless (Genome::Utility::FileSystem->create_directory($composed_dir)) {
        $self->error_message('Failed to make composed directory '. $composed_dir .":  $!");
        return;
    }
    unless (Genome::Model::Tools::RefCov::Compose->execute(
                                                           snapshot_directories => \@snapshots,
                                                           composed_directory => $composed_dir,
                                                       )) {
        $self->error_message('Failed to execute compose on ref-cov snapshots.');
        return;
    }
    return $self->verify_successful_completion;
}

sub verify_successful_completion {
    my $self = shift;
    my $build = $self->build;
    #TODO: Defined what should exist after execution... each snapshot directory with stats/FROZEN??
    
    #unless (-d $build->reference_coverage_directory .'/FROZEN') {
    #    $self->error_message('Failed to find frozen directory');
    #    return;
    #}
    #unless (-e $build->reference_coverage_directory .'/STATS.tsv') {
    #    $self->error_message('Failed to find stats file');
    #    return;
    #}
    return 1;
}


1;
