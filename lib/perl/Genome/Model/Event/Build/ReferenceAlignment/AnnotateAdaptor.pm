package Genome::Model::Event::Build::ReferenceAlignment::AnnotateAdaptor;

use strict;
use warnings;
use IO::File;
use File::Copy;
use DateTime;

use Genome;
use Carp;

class Genome::Model::Event::Build::ReferenceAlignment::AnnotateAdaptor{
    is => ['Genome::Model::Event'],
    has => [
    analysis_base_path => {
        doc => "the path at which all analysis output is stored",
        calculate_from => ['build'],
        calculate      => q|
        return $build->snp_related_metric_directory;
        |,
        is_constant => 1,
    },
    filtered_snp_output_file => {
        doc => "",
        calculate_from => ['analysis_base_path'],
        calculate      => q|
        return $analysis_base_path .'/snps_all_sequences.filtered.bed';
        |,
    },
    filtered_indel_output_file => {
        doc => "Location of filtered indels from variant detection",
        calculate_from => ['analysis_base_path'],
        calculate => q|
        return $analysis_base_path . '/indels_all_sequences.filtered.bed';
        |,
    },
    pre_annotation_filtered_variant_file => {
        doc => "Adapted variants fit for use by the annotator",
        calculate_from => ['analysis_base_path'],
        calculate      => q|
        return $analysis_base_path .'/filtered.variants.pre_annotation';
        |,
    },  
    ],
};

# TODO For now, this is hard-coded to 8 GB since the variant file isn't available when the build
# is started (which is when this method gets run, unfortunately). Logic that would either use
# a file-based Unix sort or bsub with appropriate request will require a new version of the
# annotator.
sub bsub_rusage {
    my $self = shift;
    my $mem_kb = 8_388_608; # 8 GB
    my $mem_mb = $mem_kb * 1024;
    my $cpus = 1;
    my $queue = "long";

    my $select = "select[ncpus >= $cpus && mem >= $mem_mb] span[hosts=1]";
    my $rusage = "rusage[mem=$mem_mb]";
    my $options = "-M $mem_kb -n $cpus -q $queue";
    
    my $required_usage = "-R '$select $rusage' $options";
    return $required_usage;
}

sub execute{
    my $self = shift;

    my $model = $self->model;
    my $pp = $model->processing_profile;
    
    my $annotator_version = $pp->transcript_variant_annotator_version;
    my $adaptor_version = "Genome::Model::Tools::Annotate::TranscriptVariants::Version" . $annotator_version . "::BedToAnnotation";

    my $adaptor = $adaptor_version->create(
        snv_file => $self->filtered_snp_output_file,
        indel_file => $self->filtered_indel_output_file,
        output => $self->pre_annotation_filtered_variant_file,
    );
    unless ($adaptor) {
        confess "Could not create annotation adaptor object!";
    }

    my $rv = $adaptor->execute;
    unless ($rv == 1) {
        confess "Problem executing annotation adaptor!";
    }
    
    unless( $self->check_for_existence($self->pre_annotation_filtered_variant_file) ){
        $self->error_message("filtered variant output file from find variations step doesn't exist");
        return;
    } 

    return 1;
}

1;
