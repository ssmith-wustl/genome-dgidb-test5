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

    my $annotator_verison;
    eval {
        my $build = $self->build;
        my $model = $build->model;
        my $pp = $model->processing_profile;
        $annotator_verison = $pp->transcript_variant_annotator_version;
        #unless (defined $annotator_version) {
        #    my $prop_meta = Genome::Model::Tools::Annotate::TranscriptVariants->__meta__->property_meta_for_name('use_version');
        #    $annotator_version = $prop_meta->default_value;
        #}
        
        my %available_versions = map { $_ => 1 } Genome::Model::Tools::Annotate::TranscriptVariants->available_versions;
        unless ($available_versions{$annotator_version}) {
            die "Requested annotator version ($annotator_version) is not in the list of available versions: "
                . join(', ',keys(%available_versions));
        }
        1;
    };
    if ($@) {
        $self->error_message("Could not determine which version of the Transcript Variants annotator to use: $@");
        return;
    }
    
    my $annotator = Genome::Model::Tools::Annotate::TranscriptVariants->create(
        variant_file => $self->pre_annotation_filtered_snp_file,
        output_file => $self->post_annotation_filtered_snp_file,
        annotation_filter => 'top',
        no_headers => 1,
        reference_transcripts => $self->model->annotation_reference_transcripts,
        use_version => $annotator_version,
    );

    my $rv = $annotator->execute;
    unless ($rv){
        $self->error_message("annotation of adapted filtered snp file failed");
        return;
    }
    return 1;
}

1;
