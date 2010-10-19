package Genome::Model::Tools::RunEgap;

use strict;
use warnings;

use Genome;
use Workflow::Simple;

use Carp 'confess';
use File::Temp 'tempdir';

class Genome::Model::Tools::RunEgap {
    is => 'EGAP::Command',
    has => [
        contig_fasta_file => {
            is => 'Path',
            doc => 'Path to fasta file containing contigs of an assembly',
        },
        raw_output_directory => {
            is => 'Path',
            doc => 'Directory in which predictor raw output is placed',
        },
        split_fastas_output_directory => {
            is => 'Path',
            doc => 'Split and masked fastas are put in this directory',
        },
        rna_prediction_file => {
            is => 'Path',
            doc => 'File in which parsed rna gene predictions should be placed',
        },
        coding_gene_prediction_file => {
            is => 'Path',
            doc => 'File in which parsed coding gene predictions should be placed',
        },
        exon_prediction_file => {
            is => 'Path',
            doc => 'Exon predictions written to this file',
        },
        transcript_prediction_file => {
            is => 'Path',
            doc => 'Transcript predictions written to this file',
        },
        protein_prediction_file => {
            is => 'Path',
            doc => 'Protein predictions written to this file',
        },
        snap_models => {
            is => 'Text',
            doc => 'Paths to model files used by SNAP, comma delimited',
        },
        fgenesh_model => {
            is => 'Path',
            doc => 'Path to model file to be used by fgenesh',
        },
        repeat_library => {
            is => 'Text',
            doc => 'Repeat library to be used by repeat masker',
        },
    ],
    has_optional => [
        species => { 
            is => 'Text',
            doc => 'Species being analyzed by pipeline',
        },
        xsmall => {
            is => 'Text',
            doc => 'Some parameter needed for repeat masker',
            default => 0,
        },
        max_bases_per_fasta => {
            is => 'Number',
            default => 5000000,
            doc => 'Maximum number of bases allowed per split fasta',
        },
        # TODO Probably needs some sort of default, running a workflow without logging is not a good idea
        workflow_log_directory => {
            is => 'Path',
            doc => 'Workflow logs are placed in this directory',
        },
        domain => {
            is => 'Text',
            doc => 'Domain of organism being analyzed',
            default => 'eukaryota',
            valid_values => ['eukaryota', 'archaea', 'bacteria', 'virus'],
        },
        workflow_xml_file => {
            is => 'Path',
            doc => 'Points to the workflow file to be used',
            default => '/gscmnt/temp212/info/annotation/PIPELINE/egap.xml',
        },
    ],
};

sub help_brief {
    return "Kicks off the EGAP gene prediction workflow";
}

sub help_synopsis {
    return "Kicks off the EGAP gene prediction workflow\n";
}

sub help_detail {
    return <<EOS
This command kicks off the EGAP gene prediction workflow, which runs 
several RNA and gene prediction tools, including SNAP and fgenesh.
EOS
}

sub execute {
    my $self = shift;

    $self->status_message("Kicking off EGAP workflow, using definition at " . $self->workflow_xml_file);

    my $workflow = Workflow::Operation->create_from_xml($self->workflow_xml_file);
    confess 'Could not create workflow object!' unless $workflow;

    $workflow->log_dir($self->workflow_log_directory) if defined $self->workflow_log_directory;

    my $output = run_workflow_lsf(
        $workflow,
        repeat_library => $self->repeat_library,
        xsmall => $self->xsmall,
        domain => $self->domain,
        contig_fasta => $self->contig_fasta_file,
        max_bases_per_fasta => $self->max_bases_per_fasta,
        split_fastas_output_directory => $self->split_fastas_output_directory,
        raw_output_directory => $self->raw_output_directory,
        rna_prediction_file => $self->rna_prediction_file,
        coding_gene_prediction_file => $self->coding_gene_prediction_file,
        transcript_prediction_file => $self->transcript_prediction_file,
        protein_prediction_file => $self->protein_prediction_file,
        exon_prediction_file => $self->exon_prediction_file,
        snap_models => $self->snap_models,
        fgenesh_model => $self->fgenesh_model,
    );

    if (@Workflow::Simple::ERROR or not defined $output) {
        for my $error (@Workflow::Simple::ERROR) {
            my $msg = join("\n", $error->name(), $error->error(), $error->stdout(), $error->stderr());
            $self->error_message($msg);
        }

        confess "Workflow errors encountered!";
    }

    return 1;
}

1;
