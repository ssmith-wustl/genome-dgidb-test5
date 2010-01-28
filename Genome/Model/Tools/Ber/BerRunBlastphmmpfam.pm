package Genome::Model::Tools::Ber::BerRunBlastphmmpfam;

use strict;
use warnings;

use Genome;
use Command;

use Carp;
use English;
use Bio::SeqIO;
use Bio::Seq;
use Bio::DB::BioDB;
use Bio::DB::Query::BioQuery;

use Workflow;
use Workflow::Simple;
use Data::Dumper;
use IO::File;
use IPC::Run qw/ run timeout /;
use Time::HiRes qw(sleep);
use File::Slurp;
use File::Temp;

use Cwd;

## FIXME: locus_tag isn't used at all here.

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is         => 'Command',
    has        => [
        'locus_tag' => {
            is  => 'String',
            doc => "Locus tag for project, containing DFT/FNL postpended",
        },
        'proteinnamefile' => {
            is  => 'String',
            doc => "Protein name file for all genes dumped from BioSQL",
        },
        'fastadirpath' => {
            is  => 'String',
            doc => "fasta directory path",
        },
        'berdirpath' => {
            is  => 'String',
            doc => "blastp directory path",
        },
        'hmmdirpath' => {
            is  => 'String',
            doc => "hmmpfam directory path",
        },
        'bsubfiledirpath' => {
            is  => 'String',
            doc => "bsub error files directory path",
        },
        'blpqueryfile' => {
            is  => 'String',
            doc => "blastp query file",
        },
        'hmmdatabase' => {
            is  => 'String',
            doc => "hmmpfam query file",
        },
    ]
);

sub help_brief
{
    "Tool for Running Blastp and hmmpfam for BER product naming pipeline";
}

sub help_synopsis
{
    return <<"EOS"
      Tool for Running Blastp and hmmpfam for BER product naming pipeline.
EOS
}

sub help_detail
{
    return <<"EOS"
Tool for Running Blastp and hmmpfam for BER product naming pipeline.
EOS
}

sub execute
{
    my $self = shift;

#    my @berrunblastphmmpfam = $self->gather_details();
    my @sequence_names = $self->get_sequence_names();
    my $i = 0;
#    print STDERR
#                   "berdirpath ", $self->berdirpath,"\n",
#                   "hmmdirpath ", $self->hmmdirpath,"\n",
#                   "blastp query file " , $self->blpqueryfile,"\n",
#                   "hmm database " , $self->hmmdatabase,"\n",
#                   "fasta dir " , $self->fastadirpath , "\n",
#                   "seq names " , "[ ", join(',',@sequence_names)," ]\n";

    # FIXME: need to check existance on the files and paths
    my ($wfxml_fh,$wfxml) = File::Temp::tempfile("ber-blast-hmmpfam-XXXXXX", DIR => $self->berdirpath , SUFFIX => '.xml');
    $self->status_message("starting blastp/hmmpfam jobs");
    write_file($wfxml,$self->workflowxml() );
    my $result = run_workflow_lsf( $wfxml,
                   berdirpath => $self->berdirpath,
                   hmmdirpath => $self->hmmdirpath,
                   'blastp query file' => $self->blpqueryfile,
                   'hmm database' => $self->hmmdatabase,
                   'fasta dir' => $self->fastadirpath ,
                   'seq names' => \@sequence_names,
                     );

    unless(defined($result))
    {
        foreach my $error (@Workflow::Simple::ERROR) {
            $self->error_message( join("\t",
                                       $error->dispatch_identifier(),
                                       $error->name(),
                                       $error->start_time(),
                                       $error->end_time(),
                                       $error->exit_code(),
                                      )
                                );
            $self->error_message( $error->stdout() );
            $self->error_message( $error->stderr() );
        }
        croak;
    }

    return 1;

}

sub gather_details
{
    my $self            = shift;
    my $locus_tag       = $self->locus_tag;
    my $proteinnamefile = $self->proteinnamefile;
    my $fastadirpath    = $self->fastadirpath;
    my $berdirpath      = $self->berdirpath;
    my $hmmdirpath      = $self->hmmdirpath;
    my $bsubfiledirpath = $self->bsubfiledirpath;
    my $blpqueryfile    = $self->blpqueryfile;
    my $hmmdatabase     = $self->hmmdatabase;

    my @allipc;
    my $cwd = getcwd();
    unless ( $cwd eq $fastadirpath )
    {
        chdir($fastadirpath)
            or croak
            "Failed to change to '$fastadirpath', from BerRunBlastphmmpfam.pm: $OS_ERROR";
    }

    $proteinnamefile = qq{$fastadirpath/$proteinnamefile};
    unless ( -e $proteinnamefile )
    {
        croak
            qq{\n\n NO, $proteinnamefile file found, from BerRunBlastphmmpfam.pm : $OS_ERROR \n\n};
    }
    my $proteinnamefile_fh = IO::File->new();
    $proteinnamefile_fh->open("<$proteinnamefile")
        or croak
        "Can't open '$proteinnamefile' from BerRunBlastphmmpfam.pm : $OS_ERROR";

    my $blpcount  = 0;
    my $hmpfcount = 0;

    # FIXME: this so needs to be turned into a workflow.
    while ( my $line = <$proteinnamefile_fh> )
    {

        chomp($line);
        my $file = qq{$fastadirpath/$line};

        unless ( -e $file )
        {
            croak
                qq{\n\n NO, $file, found for blastp from BerRunBlastphmmpfam.pm : $OS_ERROR \n\n };
        }

        #blastp send to lsf

        my $blpout = qq{$berdirpath/$line.nr};
        my $blperr = qq{$bsubfiledirpath/bsub.err.blp.$line};

        my @blastpcmd = ( 'blastp', $blpqueryfile, $file, );

        my $Rbp = qq {rusage[mem=4096]};

        my @bsubcmdbp = (
            'bsub', '-o', $blpout, '-e', $blperr, '-q',
            'long', '-n', '1',     '-R', $Rbp,    @blastpcmd,
        );

        $blpcount++;

        my @bpipc = ( \@bsubcmdbp, \undef, '2>&1', );

        push( @allipc, \@bpipc );

        #hmmpfam send to lsf

        my $hmpfmout = qq{$hmmdirpath/$line.hmmpfam};
        my $hmpfmerr = qq{$bsubfiledirpath/bsub.err.hmm.$line};

        my @hmmpfcmd = ( 'hmmpfam', '--cpu', '1', $hmmdatabase, $file, );

        my @bsubcmdhf = (
            'bsub',    '-o', $hmpfmout, '-e',
            $hmpfmerr, '-q', 'long',    '-n',
            '1',       '-R', $Rbp,      @hmmpfcmd,
        );

        my @hmmpfipc = ( \@bsubcmdhf, \undef, '2>&1', );

        push( @allipc, \@hmmpfipc );

    }

    return @allipc;

}

sub get_sequence_names
{
    my $self = shift;
    my $protnamefile = $self->proteinnamefile;
    # FIXME: check existance of $self->proteinnamefile.  It should be the full path,
    # and not just some filename....
    my @names = read_file($protnamefile) or croak "can't open $protnamefile : $OS_ERROR";
    chomp @names;
    return @names;
}

sub workflowxml
{
    my $self = shift;
    return qq(<?xml version='1.0' standalone='yes'?>
<workflow name="BER blastp and hmmpfam">

  <link fromOperation="input connector" fromProperty="berdirpath" toOperation="BER Blastp" toProperty="berdirpath" />
  <link fromOperation="input connector" fromProperty="hmmdirpath" toOperation="BER Hmmpfam" toProperty="hmmdirpath" />

  <link fromOperation="input connector" fromProperty="blastp query file" toOperation="BER Blastp" toProperty="blastp_query" />
  <link fromOperation="input connector" fromProperty="hmm database" toOperation="BER Hmmpfam" toProperty="hmm_database" />
  <link fromOperation="input connector" fromProperty="fasta dir" toOperation="BER Hmmpfam" toProperty="fasta_dir" />
  <link fromOperation="input connector" fromProperty="fasta dir" toOperation="BER Blastp" toProperty="fastadir" />
  <link fromOperation="input connector" fromProperty="seq names" toOperation="BER Hmmpfam" toProperty="sequence_names" />
  <link fromOperation="input connector" fromProperty="seq names" toOperation="BER Blastp" toProperty="sequence_names" />
  <link fromOperation="BER Blastp" fromProperty="success" toOperation="output connector" toProperty="blastp_success" />
  <link fromOperation="BER Hmmpfam" fromProperty="success" toOperation="output connector" toProperty="hmmpfam_success" />

  <operation name="BER Hmmpfam">
     <operationtype commandClass="PAP::Command::Hmmpfam" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="BER Blastp">
     <operationtype commandClass="PAP::Command::BerBlastp" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>berdirpath</inputproperty>
    <inputproperty>hmmdirpath</inputproperty>
    <inputproperty>blastp query file</inputproperty>
    <inputproperty>hmm database</inputproperty>
    <inputproperty>seq names</inputproperty>
    <inputproperty>fasta dir</inputproperty>

    <outputproperty>blastp_success</outputproperty>
    <outputproperty>hmmpfam_success</outputproperty>
    <outputproperty>result</outputproperty>
  </operationtype>


</workflow>

    );

}

1;

__DATA__
<?xml version='1.0' standalone='yes'?>
<workflow name="BER blastp and hmmpfam">

  <link fromOperation="input connector" fromProperty="berdirpath" toOperation="BER Blastp" toProperty="berdirpath" />
  <link fromOperation="input connector" fromProperty="hmmdirpath" toOperation="BER Hmmpfam" toProperty="hmmdirpath" />

  <link fromOperation="input connector" fromProperty="blastp query file" toOperation="BER Blastp" toProperty="blastp_query" />
  <link fromOperation="input connector" fromProperty="hmm database" toOperation="BER Hmmpfam" toProperty="hmm_database" />
  <link fromOperation="input connector" fromProperty="fasta dir" toOperation="BER Hmmpfam" toProperty="fasta_dir" />
  <link fromOperation="input connector" fromProperty="fasta dir" toOperation="BER Blastp" toProperty="fastadir" />
  <link fromOperation="input connector" fromProperty="seq names" toOperation="BER Hmmpfam" toProperty="sequence_names" />
  <link fromOperation="input connector" fromProperty="seq names" toOperation="BER Blastp" toProperty="sequence_names" />
  <link fromOperation="BER Blastp" fromProperty="success" toOperation="output connector" toProperty="blastp_success" />
  <link fromOperation="BER Hmmpfam" fromProperty="success" toOperation="output connector" toProperty="hmmpfam_success" />

  <operation name="BER Hmmpfam">
     <operationtype commandClass="PAP::Command::Hmmpfam" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="BER Blastp">
     <operationtype commandClass="PAP::Command::BerBlastp" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>berdirpath</inputproperty>
    <inputproperty>hmmdirpath</inputproperty>
    <inputproperty>blastp query file</inputproperty>
    <inputproperty>hmm database</inputproperty>
    <inputproperty>seq names</inputproperty>
    <inputproperty>fasta dir</inputproperty>

    <outputproperty>blastp_success</outputproperty>
    <outputproperty>hmmpfam_success</outputproperty>
    <outputproperty>result</outputproperty>
  </operationtype>


</workflow>
