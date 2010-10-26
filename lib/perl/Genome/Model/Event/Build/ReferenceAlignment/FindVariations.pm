package Genome::Model::Event::Build::ReferenceAlignment::FindVariations;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::FindVariations {
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
    ],
};

sub bsub_rusage {
    my $self = shift;
    
    #TODO Eventually this will be replaced by a mini-workflow and then won't need to reserve all these resources itself.
    return "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>1000 && mem>16000] span[hosts=1] rusage[tmp=1000:mem=16000]' -M 1610612736";
    
    #my $detector_class = $self->detector_class([NAME HERE]);
    #
    #return $detector_class->__meta__->property('lsf_resource')->default_value;
}

sub detector_class {
    my $self = shift;
    my $detector_name = shift;

    my $model = $self->model;

    unless($detector_name) {
        $self->error_message("No variant detector name provided for model name/id: " . $model->name . " " . $model->genome_model_id);
        die;
    }
    
    my $detector_module_name = #Convert things like "foo-bar" to "FooBar"
            join ("", map { ucfirst(lc($_)) } split(/-/,$detector_name) );

    my $detector_class = 'Genome::Model::Tools::DetectVariants::' . $detector_module_name;

    return $detector_class;
}

sub execute {
    my $self = shift;

    my $model = $self->model;
    my $snv_detector_name = $model->snv_detector_name;
    my $indel_detector_name = $model->indel_detector_name;
    my $snv_detector_version = $model->snv_detector_version;
    my $indel_detector_version = $model->indel_detector_version;

    # TODO for now just run snps and indels, eventually run sv etc
    my $result;
    if ( (defined $snv_detector_name && defined $indel_detector_name) and ($snv_detector_name eq $indel_detector_name) and ($snv_detector_version eq $indel_detector_version) ) {
        # Snp and indel name and version are the same, so do both at once
        $result = $self->_run_variant_detector($snv_detector_name, $snv_detector_version, 1, 1);
    } else {
        # Detect snps if requested
        $result = 1;
        if (defined $snv_detector_name) {
            $result &&= $self->_run_variant_detector($snv_detector_name, $snv_detector_version, 1, 0);
        }
        # detect indels if requested
        if (defined $indel_detector_name) {
            $result &&= $self->_run_variant_detector($indel_detector_name, $indel_detector_version, 0, 1);
        }
    }

    return $result;
}

# This method takes a boolean flag for detect_snps and detect_indels, both can be 1
sub _run_variant_detector {
    my ($self, $detector_name, $detector_version, $detect_snvs, $detect_indels) = @_;

    my $detector_class = $self->detector_class($detector_name);

    my $model = $self->model;
    my $build = $self->build;
    my $reference_build = $model->reference_sequence_build;
    my $reference_sequence = $reference_build->full_consensus_path('fa');
    my $aligned_reads_input = $build->whole_rmdup_bam_file;
    my $snv_params = $model->snv_detector_params;
    my $indel_params = $model->indel_detector_params;

    #TODO Horrbile MAQ hack attack!!
    #Once we've standardized on an input/output format for these tools, maybe we can get rid of this icky special case
    if($detector_name eq 'maq') {
        $aligned_reads_input = $build->whole_rmdup_map_file;
        $reference_sequence = $reference_build->full_consensus_path('bfa');
    }

    my $detector = $detector_class->create(
        snv_params => $snv_params,
        indel_params => $indel_params,
        detect_snvs => $detect_snvs,
        detect_indels => $detect_indels,
        aligned_reads_input => $aligned_reads_input,
        output_directory => $self->analysis_base_path, 
        reference_sequence_input => $reference_sequence,
        version => $detector_version,
    );

    unless($detector->execute()) {
        $self->error_message($detector->error_message);
        return;
    }

    # Set metrics.
    my $metrics = $detector->generate_metrics;
    unless (ref $metrics eq 'HASH') {
        $self->error_message("generate_metrics returned a bad error code");
        return;
    }

    for my $metric (keys %$metrics) {
        $self->add_metric(name => $metric, value => $metrics->{$metric});
    }

    return 1;
}


1;

