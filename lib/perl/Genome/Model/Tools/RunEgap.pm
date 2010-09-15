package Genome::Model::Tools::RunEgap;

use strict;
use warnings;

use Genome;
use Carp;
use Workflow::Simple;

class Genome::Model::Tools::RunEgap {
    is => 'EGAP::Command',
    has => [
        sequence_set_id => {
            is => 'Text',
            doc => 'Sequence set ID used to gather sequence and other information from database',
        },
        fgenesh_model => {
            is => 'Path',
            doc => 'Path to HMM file used by fgenesh',
        },
        snap_models => {
            is => 'Path',
            doc => 'Path to HMM file used by SNAP',
        },
        output_directory => {
            is => 'Path',
            doc => 'Pipeline output is placed in this directory and several subdirectories',
        },
    ],
    has_optional => [
        domain => {
            is => 'Text',
            doc => 'Domain of organism being analyzed',
            default => 'eukaryota',
            valid_values => ['eukaryota', 'archaea', 'bacteria', 'virus'],
        },
        snap_version => {
            is => 'Text',
            doc => 'Version of SNAP to use',
            default => '2010-07-28',
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

    # TODO Make a workflow object and set its log directory here. Having a default location
    # in the xml definition isn't the best way...
    my $output = run_workflow_lsf(
        $self->workflow_xml_file,
        'output directory' => $self->output_directory,
        'seq set id'=> $self->sequence_set_id,
        'domain' => $self->domain,
        'fgenesh model' => $self->fgenesh_model,
        'snap models' => $self->snap_models,
        'snap version' => $self->snap_version,
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
