package Genome::Model::SomaticVariation::Command::DetectVariants;

use strict;
use warnings;
use Genome;

class Genome::Model::SomaticVariation::Command::DetectVariants{
    is => 'Genome::Command::Base',
    has =>[
        build_id => {
            is => 'Integer',
            is_input => 1,
            is_output => 1,
            doc => 'build id of SomaticVariation model',
        },
        build => {
            is => 'Genome::Model::Build::SomaticVariation',
            id_by => 'build_id',
        },
    ],
};

sub execute{
    my $self = shift;
    my $build = $self->build;
    unless ($build){
        die $self->error_message("no build provided!");
    }

    my %params;
    $params{snv_detection_strategy} = $build->snv_detection_strategy if $build->snv_detection_strategy;
    $params{indel_detection_strategy} = $build->indel_detection_strategy if $build->indel_detection_strategy;
    $params{sv_detection_strategy} = $build->sv_detection_strategy if $build->sv_detection_strategy;
    
    my $tumor_bam = $build->tumor_bam;
    unless (-e $tumor_bam){
        die $self->error_message("No tumor bam found for somatic model");
    }
    $params{aligned_reads_input} = $tumor_bam;

    my $reference_build = $build->reference_sequence_build;
    my $reference_fasta = $reference_build->fasta_file;
    unless(-e $reference_fasta){
        die $self->error_message("fasta file for reference build doesn't exist!");
    }
    $params{reference_sequence_input} = $reference_fasta;
    
    my $normal_bam = $build->normal_bam;
    unless (-e $normal_bam){
        die $self->error_message("No normal bam found for somatic model");
    }
    $params{control_aligned_reads_input} = $normal_bam;

    my $output_dir = $build->data_directory."/variants";
    $params{output_directory} = $output_dir;

    my $command = Genome::Model::Tools::DetectVariants2::Dispatcher->create(%params);
    unless ($command){
        die $self->error_message("Couldn't create detect variants dispatcher from params:\n".Data::Dumper::Dumper \%params);
    }
    my $rv = $command->execute;
    my $err = $@;
    unless ($rv){
        die $self->error_message("Failed to execute detect variants dispatcher(err:$@) with params:\n".Data::Dumper::Dumper \%params);
    }
    return 1;
}

1;

