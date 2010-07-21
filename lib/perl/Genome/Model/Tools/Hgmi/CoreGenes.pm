package Genome::Model::Tools::Hgmi::CoreGenes;

use strict;
use warnings;

use Genome;
use Command;
use Carp;
use Bio::Seq;
use Bio::SeqIO;
use English;

use File::Copy;
use Cwd;
use IPC::Run;
use File::Slurp;
use File::Temp qw/ tempfile tempdir /;


UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
        has => [
            'cell_type'  => { is => 'String',
                                  doc => "Type of genome to check; either ARCHEA or BACTERIA",
            },
            'sequence_set_id' => { is => 'String',
                    doc => "sequence set id of organism",
            },
            'dev' => { is => 'Boolean',
                       doc => "development flag",
                       is_optional => 1,
                       default => 0,
            },
    ],
);


sub help_brief
{
    "run the core genes screen after everything has been finished.";
}

sub help_synopsis
{
    my $self = shift;
    return <<"EOS"
need to put help synopsis here
EOS
}

sub help_detail
{
    my $self = shift;
    return <<"EOS"
need to put help detail here.
EOS
}


#sub create
#{
#    my $self = shift;
#    
#    return 1;
#}

sub execute
{
    my $self = shift;
    #my $sequences = $self->sequences;

    # bap_export_proteins should be deployed.
    my @pep_export = (
                     # '/gsc/scripts/gsc/annotation/bap_export_proteins',
                      'gmt','bacterial','export-proteins',
                      '--sequence-set-id', 
                      $self->sequence_set_id(),

        );

    if($self->dev)
    {
        push(@pep_export,'--dev');
    }
    my ($stdout,$stderr);
    IPC::Run::run(
        \@pep_export,
        '>',
        \$stdout,
        '2>',
        \$stderr,
      );


    # write out what's in $stdout
    my ($tempfh, $tempfasta) = tempfile("coregenesXXXXXX", DIR => './');
    write_file($tempfasta,$stdout);

    my ($typeflag,$percent_id,$coverage);
    if($self->cell_type =~ /BACTER/)
    {
        #$typeflag = '-bact';
        $typeflag = 'bact';
        $percent_id  = 30;
        $coverage = 0.3;
    }
    else
    {
        #$typeflag = '-archaea';
        $typeflag = 'archaea';
        $percent_id  = 50;
        $coverage = 0.7;
    }
    my @core_genes = ('/gsc/scripts/bin/run_coregene_cov_pid_script',
                      $tempfasta,
                      $percent_id,
                      $coverage,
                      '-geneset',
                      $typeflag,
        );

    # eventually change this to a module call.
    @core_genes = ('gmt','bacterial','core-gene-coverage',
                   '--fasta-file', $tempfasta,
                   '--pid' , $percent_id,
                   '--option', 'geneset',
                   '--fol', $coverage,
                   '--genome',$typeflag );

    my $results;
    IPC::Run::run(
        \@core_genes,
        '>',
        \$results,
        '2>',
        \$stderr,
      ) or croak "\n\nfailed to run core genes screen script ... CoreGenes.pm\n\n";

    write_file('Coregene_results',$results);
    unless($results =~ /PASSED/)
    {
        $self->error_message("core genes check fail:");
        $self->error_message("$results");
        croak "\n\nWARNING: core genes did not pass:\n$results ... CoreGenes.pm\n\n";
    }
    $self->status_message("Core gene results passed");
    $self->status_message($results);    
    return 1;
}

1;

# $Id$
