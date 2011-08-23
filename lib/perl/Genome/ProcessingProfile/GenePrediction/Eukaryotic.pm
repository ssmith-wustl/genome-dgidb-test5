package Genome::ProcessingProfile::GenePrediction::Eukaryotic;

use strict;
use warnings;
use Genome;
use Carp 'confess';

class Genome::ProcessingProfile::GenePrediction::Eukaryotic {
    is => 'Genome::ProcessingProfile::GenePrediction',
    has_param => [
        max_bases_per_fasta => {
            is => 'Number',
            is_optional => 1,
            default => 5000000,
            doc => 'Maximum allowable base pairs in a fasta file, used for fasta splitting',
        },
        xsmall => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
            doc => 'If set to true, lower-case masking characters are used by repeat masker instead of N',
        },
        rnammer_version => {
            is => 'Text',
            is_optional => 1,
            default => '1.2.1', 
            doc => 'Version of rnammer predictor to use',
        },
        rfamscan_version => {
            is => 'Text',
            is_optional => 1,
            valid_values => ['7.0', '8.0', '8.1', '8.1.skip_introns'],
            default => '8.1.skip_introns',
            doc => 'Version of rfamscan predictor to use',
        },
        snap_version => {
            is => 'Text',
            is_optional => 1,
            valid_values => ['2004-06-17', '2007-12-18', '2010-07-28'],
            default => '2010-07-28',
            doc => 'Version of SNAP predictor to use',
        },
        skip_masking_if_no_rna => {
            is => 'Boolean',
            is_optional => 1,
            default => 1,
            doc => 'If set, rna sequence masking is skipped if no rna files are found. If this is false, not ' .
                   'finding an rna file is a fatal error',
        },
        skip_repeat_masker => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
            doc => 'If set, the repeat masker step is skipped',
        },
    ],
};

sub _resolve_type_name_for_class {
    return "gene prediction";
}

sub _resolve_workflow_for_build { 
    my ($self, $build) = @_;

    my $xml = __FILE__ . '.xml';
    confess "Did not find workflow xml file at $xml!" unless -e $xml;

    my $workflow = Workflow::Operation->create_from_xml($xml);
    confess "Could not create workflow object from $xml!" unless $workflow;

    $workflow->log_dir($build->log_directory);
    $workflow->name($build->workflow_name);

    return $workflow;
}

sub _map_workflow_inputs {
    my ($self, $build) = @_;
    my $model = $build->model;
    confess "Could not get model from build " . $build->build_id unless $model;

    my @inputs;

    push @inputs,
        domain => $self->domain,
        max_bases_per_fasta => $self->max_bases_per_fasta,
        xsmall => $self->xsmall,
        rnammer_version => $self->rnammer_version,
        rfamscan_version => $self->rfamscan_version,
        snap_version =>  $self->snap_version,
        skip_masking_if_no_rna => $self->skip_masking_if_no_rna,
        repeat_library => $model->repeat_library,
        snap_models => $model->snap_models,
        fgenesh_model => $model->fgenesh_model,
        contig_fasta => $model->assembly_contigs_file,
        split_fastas_output_directory => $build->split_fastas_output_directory,
        raw_output_directory => $build->raw_output_directory,
        prediction_directory => $build->prediction_directory,
        skip_repeat_masker => $self->skip_repeat_masker,
        repeat_masker_ace_file => $build->repeat_masker_ace_file,
        predictions_ace_file => $build->predictions_ace_file,
        rna_predictions_ace_file => $build->rna_predictions_ace_file,
        rna_predictions_only_flag => 1; # This is just used to tell the step makes the rna predictions ace
                                        # file to only look at rna. There's unfortunately no other way I'm
                                        # aware of that'll do this, and since this same module is used to
                                        # create the coding gene predictions ace file too, I can't change
                                        # the default value of the module itself.

    my $params;
    for (my $i = 0; $i < (scalar @inputs); $i += 2) {
        $params .= $inputs[$i] . " : " . $inputs[$i + 1] . "\n";
    }
    $self->status_message("Parameters for workflow are: \n$params");

    return @inputs;
}

1;

