package Genome::Model::Tools::RunEgap;

use strict;
use warnings;

use Genome;
use Workflow::Simple;

use Carp 'confess';
use File::Temp 'tempdir';
use File::Path 'make_path';

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
        prediction_directory => {
            is => 'Path',
            doc => 'Predictions (RNA, coding gene, transcript, etc) are written to files in this directory',
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
            default => 'eukaryotic',
            valid_values => ['eukaryotic', 'archaeal', 'bacterial', 'viral'],
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

    for my $dir ($self->split_fastas_output_directory, $self->raw_output_directory, $self->prediction_directory, $self->workflow_log_directory) {
        next unless defined $dir;
        unless (-d $dir) {
            my $rv = make_path($dir);
            confess "Could not make directory $dir!" unless defined $rv and $rv;
        }
    }

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
        snap_models => $self->snap_models,
        fgenesh_model => $self->fgenesh_model,
        prediction_directory => $self->prediction_directory,
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
