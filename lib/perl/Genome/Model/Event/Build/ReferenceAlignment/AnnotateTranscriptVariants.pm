package Genome::Model::Event::Build::ReferenceAlignment::AnnotateTranscriptVariants;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::AnnotateTranscriptVariants{
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
        pre_annotation_filtered_snp_file => {
            doc => "",
            calculate_from => ['analysis_base_path'],
            calculate      => q|
            return $analysis_base_path .'/filtered.variants.pre_annotation';
            |,
        },  
        post_annotation_filtered_snp_file => {
            doc => "",
            calculate_from => ['analysis_base_path'],
            calculate      => q|
            return $analysis_base_path .'/filtered.variants.post_annotation';
            |,
        }, 
    ],
};

sub execute {
    my $self = shift;
    
    unless ($self->check_for_existence($self->pre_annotation_filtered_snp_file)) {
        $self->error_message("Adapted filtered snp file does not exist for annotation");
        return;
    }

    my $annotator = Genome::Model::Tools::Annotate::TranscriptVariants->create(
        variant_file => $self->pre_annotation_filtered_snp_file,
        output_file => $self->post_annotation_filtered_snp_file,
        annotation_filter => 'top',
        no_headers => 1,
        reference_transcripts => $self->model->annotation_reference_transcripts,
    );

    my $rv = $annotator->execute;
    unless ($rv){
        $self->error_message("annotation of adapted filtered snp file failed");
        return;
    }
    return 1;
}

1;
