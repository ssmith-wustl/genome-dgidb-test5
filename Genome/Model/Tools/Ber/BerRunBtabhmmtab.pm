package Genome::Model::Tools::Ber::BerRunBtabhmmtab;

use strict;
use warnings;

use Genome;
use Command;

use Carp;
use Data::Dumper;
use English;

use File::Find;
use File::Slurp;
use File::Temp;
use Workflow::Simple;

use Cwd;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is         => 'Command',
    has        => [
        'locus_tag' => {    # is locus_tag used at all here???
            is  => 'String',
            doc => "Locus tag for project, containing DFT/FNL postpended",
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
        'srcdirpath' => {
            is  => 'String',
            doc => "src directory for the ber product naming software",
        },
    ]
);

sub help_brief
{
    "Tool for Running Btab and htap for BER product naming pipeline";
}

sub help_synopsis
{
    return <<"EOS"
      Tool for Running Btab and htab for BER product naming pipeline.
EOS
}

sub help_detail
{
    return <<"EOS"
Tool for Running Btab and htab for BER product naming pipeline.
EOS
}

sub execute
{
    my $self = shift;

    my @sequence_names = $self->get_sequence_names();

    # FIXME: use tempfile
    my ( $btab_fh, $btabxml ) = File::Temp::tempfile(
        "ber-btab-XXXXXX",
        SUFFIX => '.xml',
        DIR    => $self->berdirpath
    );
    write_file( $btabxml, $self->workflowxml() );

   #    # this way is causing problems.... ?
   #    my $w = Workflow::Model->create_from_xml(\*DATA);
   #    my $result = $w->execute( 'locus tag'       => $self->locus_tag,
   #                              'fastadir'        => $self->fastadirpath,
   #                              'berdirpath'      => $self->berdirpath,
   #                              'hmmdirpath'      => $self->hmmdirpath,
   #                              'srcdirpath'      => $self->srcdirpath,
   #                              'bsubfiledirpath' => $self->bsubfiledirpath,
   #                              'seq names'       => \@sequence_names, );

    $self->status_message("starting btab/htab jobs...");
    my $result = run_workflow_lsf(
        $btabxml,
        'locus tag'       => $self->locus_tag,
        'fastadir'        => $self->fastadirpath,
        'berdirpath'      => $self->berdirpath,
        'hmmdirpath'      => $self->hmmdirpath,
        'srcdirpath'      => $self->srcdirpath,
        'bsubfiledirpath' => $self->bsubfiledirpath,
        'seq names'       => \@sequence_names,
    );

    unless ( defined($result) )
    {
        foreach my $error (@Workflow::Simple::ERROR)
        {
            $self->error_message(
                join( "\t",
                    $error->dispatch_identifier(), $error->name(),
                    $error->start_time(),          $error->end_time(),
                    $error->exit_code(), )
            );

            $self->error_message( $error->stdout() );
            $self->error_message( $error->stderr() );
        }
        croak;
    }

    my $i = 0;

    # do a File::Find type deal here and grab the existing btab
    # and htab files for the $i count (and prehaps rename $i to
    # something more descriptive).

    # ??? do we need to worry about this???

    # in case we want to count the numbers of each type of file.
    my @storageber = ();
    my @storagehmm = ();
    find(
        sub {
            if ( $_ =~ /\.btab$/ ) { push( @storageber, $_ ); }
        },
        $self->berdirpath
    );
    find(
        sub {
            if ( $_ =~ /\.htab$/ ) { push( @storagehmm, $_ ); }
        },
        $self->hmmdirpath
    );
    $i = scalar(@storageber) + scalar(@storagehmm);

    # are the extra newlines needed????
    print "\n\nTotal for Btab/Htab: ", $i, "\n\n";

    return 1;
}

# not sure if I need this or not yet.
sub get_sequence_names
{
    my $self     = shift;
    my $fastadir = $self->fastadirpath;
    my @sequence_names;
    find(
        sub {
            if ( -f $_ ) { push( @sequence_names, $_ ); }
        },
        $fastadir
    );
    return @sequence_names;
}

sub workflowxml
{
    my $self = shift;

    return qq(<?xml version='1.0' standalone='yes'?>
<workflow name="BER btab and htab" >
  <link fromOperation="input connector" fromProperty="locus tag" toOperation="BER btabhmmtab" toProperty="locus_tag" />
  <link fromOperation="input connector" fromProperty="fastadir" toOperation="BER btabhmmtab" toProperty="fastadir" />
  <link fromOperation="input connector" fromProperty="berdirpath" toOperation="BER btabhmmtab" toProperty="berdirpath" />
  <link fromOperation="input connector" fromProperty="hmmdirpath" toOperation="BER btabhmmtab" toProperty="hmmdirpath" />
  <link fromOperation="input connector" fromProperty="srcdirpath" toOperation="BER btabhmmtab" toProperty="srcdirpath" />
  <link fromOperation="input connector" fromProperty="bsubfiledirpath" toOperation="BER btabhmmtab" toProperty="bsubfiledirpath" />
  <link fromOperation="input connector" fromProperty="seq names" toOperation="BER btabhmmtab" toProperty="sequence_names" />
  <link fromOperation="BER btabhmmtab" fromProperty="success" toOperation="output connector" toProperty="success" />

  <operation name="BER btabhmmtab">
    <operationtype commandClass="PAP::Command::BtabHmmtab" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>locus tag</inputproperty>
    <inputproperty>fastadir</inputproperty>
    <inputproperty>berdirpath</inputproperty>
    <inputproperty>hmmdirpath</inputproperty>
    <inputproperty>srcdirpath</inputproperty>
    <inputproperty>bsubfiledirpath</inputproperty>
    <inputproperty>seq names</inputproperty>
    <outputproperty>success</outputproperty>
  </operationtype>

</workflow>
);

}

1;

__DATA__
<?xml version='1.0' standalone='yes'?>
<workflow name="BER btab and htab" >
  <link fromOperation="input connector" fromProperty="locus tag" toOperation="BER btabhmmtab" toProperty="locus_tag" />
  <link fromOperation="input connector" fromProperty="fastadir" toOperation="BER btabhmmtab" toProperty="fastadir" />
  <link fromOperation="input connector" fromProperty="berdirpath" toOperation="BER btabhmmtab" toProperty="berdirpath" />
  <link fromOperation="input connector" fromProperty="hmmdirpath" toOperation="BER btabhmmtab" toProperty="hmmdirpath" />
  <link fromOperation="input connector" fromProperty="srcdirpath" toOperation="BER btabhmmtab" toProperty="srcdirpath" />
  <link fromOperation="input connector" fromProperty="bsubfiledirpath" toOperation="BER btabhmmtab" toProperty="bsubfiledirpath" />
  <link fromOperation="input connector" fromProperty="seq names" toOperation="BER btabhmmtab" toProperty="sequence_names" />
  <link fromOperation="BER btabhmmtab" fromProperty="success" toOperation="output connector" toProperty="success" />

  <operation name="BER btabhmmtab">
    <operationtype commandClass="PAP::Command::BtabHmmtab" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>locus tag</inputproperty>
    <inputproperty>fastadir</inputproperty>
    <inputproperty>berdirpath</inputproperty>
    <inputproperty>hmmdirpath</inputproperty>
    <inputproperty>srcdirpath</inputproperty>
    <inputproperty>bsubfiledirpath</inputproperty>
    <inputproperty>seq names</inputproperty>
    <outputproperty>success</outputproperty>
  </operationtype>

</workflow>
