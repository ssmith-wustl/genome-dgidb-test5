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
            log_file => {
                           doc => 'list of samples for screening',
                           is => 'String',
                           is_input => 1,
                       },
            dir     => {
                           doc => 'directory of inputs',
                           is => 'String',
                           is_input => 1,

                        },
            workflow_xml => {
                                is => 'String',
                                doc => "Workflow xml file",
                                default => '/gscmnt/sata835/info/medseq/virome/workflow/virome.xml',
                                is_optional => 1,
                            }
    ]
);

sub help_brief
{
    "Runs virome screening pipeline";
}

sub help_synopsis
{
    return <<"EOS"
    Runs virome screening pipeline.  Takes directory path, fasta and sample log.
EOS
}

sub help_detail
{
    return <<"EOS"
    Runs virome screening pipeline.  Takes directory path, fasta and sample log.
EOS
}

sub execute
{
    my $self = shift;
    my ($fasta_file, $log_file, $dir, $xml_file) = ($self->fasta_file, $self->log_file, $self->dir, $self->workflow_xml);
    my $output = run_workflow_lsf(
                              $xml_file,
                              'fasta_file'  => $fasta_file,
                              'log_file'    => $log_file,
                              'dir'         => $dir,
                          );
    return 1;
}

