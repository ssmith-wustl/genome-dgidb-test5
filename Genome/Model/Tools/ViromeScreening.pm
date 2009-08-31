package Genome::Model::Tools::ViromeScreening;

use strict;
use warnings;

use Genome;
use Command;
use Workflow::Simple;
use Data::Dumper;


UR::Object::Type->define(
    class_name => __PACKAGE__,
    is         => 'Command',
    has        => [

            fasta_file => {
                           doc => 'file of reads to be checked for contamination',
                           is => 'String',
                           is_input => 1,
                       },
            barcode_file => { 
                           doc => 'list of samples for screening',
                           is => 'String',
                           is_input => 1,
                       },
            dir     => {
                           doc => 'directory of inputs',
                           is => 'String',
                           is_input => 1,

                        },
            logfile => {
                            doc => 'output file for monitoring progress of pipeline',
                            is => 'String',
                            is_input => 1,
                        },
    ]
);

sub help_brief
{
    "Runs virome screening workflow";
}

sub help_synopsis
{
    return <<"EOS"
    genome-model tools virome-screening ... 
EOS
}

sub help_detail
{
    return <<"EOS"
    Runs the virome screening pipeline, using ViromeEvent modules.  Takes directory path, fasta, sample log, and logfile. 
EOS
}

sub execute
{
    my $self = shift;
    my ($fasta_file, $barcode_file, $dir, $logfile) = ($self->fasta_file, $self->barcode_file, $self->dir, $self->logfile);
    unlink($logfile) if (-e $logfile); 

    my $output = run_workflow_lsf(
                              '/gscmnt/sata835/info/medseq/virome/workflow/xml/virome-screening.xml',
                              'fasta_file'  => $fasta_file,
                              'barcode_file'=> $barcode_file,
                              'dir'         => $dir,
                              'logfile'     => $logfile,
                          );
    return 1;
}

