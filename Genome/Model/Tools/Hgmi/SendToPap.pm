package Genome::Model::Tools::Hgmi::SendToPap;

use strict;
use warnings;

use Genome;
use Command;
use Carp;
use File::Slurp;
use File::Temp qw/ tempfile tempdir /;
use DateTime;
use List::MoreUtils qw/ uniq /;
use Bio::SeqIO;
use Bio::Seq;
use Bio::DB::BioDB;
use Bio::DB::Query::BioQuery;
use IPC::Run;
use Workflow::Simple;
use Data::Dumper;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is         => 'Command',
    has        => [
        'locus_tag' => {
            is  => 'String',
            doc => "taxonomy name"
        },
        'sequence_set_id' => {
            is  => 'Integer',
            doc => "Sequence set id in MGAP database",
        },
        'taxon_id' => {
            is  => 'Integer',
            doc => "NCBI Taxonomy id",
            is_optional => 1,
        },
        'workflow_xml' => {
            is => 'String',
            doc => "Workflow xml file",
            is_optional => 1,
        },
        'keep_pep' => {
            is          => 'Boolean',
            doc         => "keep temporary fasta file of gene proteins",
            is_optional => 1,
            default     => 0
        },
        'pep_file' => {
            is          => 'String',
            doc         => "fasta file of gene proteins",
            is_optional => 1,
        },
        'dev' => {
            is => 'Boolean',
            doc => "use development databases",
            is_optional => 1,
        },
        'chunk_size' => {
            is => 'Integer',
            doc => "Chunk size parameter for PAP (default 10)",
            is_optional => 1,
            default => 10,
        },
    ]
);

sub help_brief
{
    "Bridges between HGMI tools and PAP";
}

sub help_synopsis
{
    return <<"EOS"
Bridges between HGMI tools and PAP.  This tool pulls data from biosql,
then initializes and runs the PAP workflow.
EOS
}

sub help_detail
{
    return <<"EOS"
Bridges between HGMI tools and PAP.  This tool loads predictions from mgap to
biosql, pulls data from biosql, then initializes and runs the PAP workflow.
EOS
}

sub execute
{
    my $self = shift;

    print STDERR "moving data from mgap to biosql\n";
    $self->mgap_to_biosql();

    print STDERR "creating peptide file\n";
    $self->get_gene_peps();

    # interface to workflow to start the PAP.
    $self->do_pap_workflow();

    return 1;
}

sub get_gene_peps
{
    my $self = shift;
    # this needs to handle switching to
    # either dev or prod
    my $dbadp;

    if($self->dev())
    {
        $dbadp = Bio::DB::BioDB->new(
            -database => 'biosql',
            -user     => 'sg_user',
            -pass     => 'sgus3r',
            -dbname   => 'DWDEV',
            -driver   => 'Oracle'
        );
    }
    else
    {
        $dbadp = Bio::DB::BioDB->new(
            -database => 'biosql',
            -user     => 'sg_user',
            -pass     => 'sg_us3r',
            -dbname   => 'DWRAC',
            -driver   => 'Oracle'
        );
    }

    my $cleanup = $self->keep_pep ? 0 : 1;
    my $tempdir = tempdir( 
                          CLEANUP => $cleanup,
                          DIR     => '/gscmnt/temp212/info/annotation/PAP_tmp',
                         );
    my ( $fh, $file ) = tempfile(
        "pap-XXXXXX",
        DIR    => $tempdir,
        SUFFIX => '.fa'
    );
    #print "tempdir: ", $tempdir, ", tempfile: ", $file, ", cleanup: ",
    #    $cleanup, "\n";
    unless(defined($self->pep_file))
    {
        $self->pep_file($file);
    }
    $file = $self->pep_file();
    my $seqout = new Bio::SeqIO(
        -file   => ">$file",
        -format => "fasta"
    );

    my $adp = $dbadp->get_object_adaptor("Bio::SeqI");

    my $query = Bio::DB::Query::BioQuery->new();
    $query->datacollections( [ "Bio::PrimarySeqI s", ] );

    my $locus_tag = $self->locus_tag;
    $query->where( ["s.display_id like '$locus_tag%'"] );
    my $res = $adp->find_by_query($query);
GENE: while ( my $seq = $res->next_object() )
    {
        my $gene_name = $seq->display_name();

        #print $gene_name, "\n";
        my @feat = $seq->get_SeqFeatures();
        foreach my $f (@feat)
        {
            my $display_name = $f->display_name();
            #print STDERR $display_name," ", $f->primary_tag,"\n";
            next GENE if $f->primary_tag ne 'gene';
            my $ss;
            $ss = $seq->subseq( $f->start, $f->end );
            my $pep = $self->make_into_pep( $f->strand,
                #$ss,
                $seq->subseq($f->start,$f->end),
                $display_name );
            $seqout->write_seq($pep);
            #print STDERR "sequence should be written out\n";
        }
    }
    if(! -f $file )
    {
        print STDERR "the fasta file $file doesn't exist!\n";
        return 0;
    }
    unless( -s $file > 0 )
    {
        print STDERR "the fasta file $file still empty!\n";
    }

    return 1;
}

sub make_into_pep
{
    my ( $self, $strand, $subseq, $name ) = @_;

    my $seq = new Bio::Seq(
        -display_id => $name,
        -seq        => $subseq
    );
    my $newseq;
    if ( $strand < 0 )
    {
        $newseq = $seq->revcom->translate->seq;
    }
    else
    {
        $newseq = $seq->translate->seq;
    }
    my $seqobj = new Bio::Seq(
        -display_id => $name,
        -seq        => $newseq
    );
    return $seqobj;
}

sub mgap_to_biosql
{
    my $self      = shift;
    my $locus_tag = $self->locus_tag;
    my $ssid      = $self->sequence_set_id;
    my $taxid     = $self->taxon_id;
    my $testnorun = shift;
    my @command = (
        'bap_load_biosql', '--sequence-set-id', $ssid,
        #'--tax-id',        $taxid,
    );

    if(defined($taxid))
    {
        push(@command, '--tax-id');
        push(@command, $taxid);
    }

    if($self->dev)
    {
        push(@command,'--dev');
        push(@command,'--biosql-dev');
    }
    my ($cmd_out,$cmd_err);

    if($testnorun)
    {
        # just for testing.
        print join(" " , @command),"\n";;
        return 1;
    }

    IPC::Run::run(
        \@command,
        \undef,
        '>',
        \$cmd_out,
        '2>',
        \$cmd_err,
    ) or croak "can't load biosql from mgap!!!\n$cmd_err";

    print STDERR $cmd_err,"\n";
    return 1;

}

## need workflow item here...

sub do_pap_workflow
{
    my $self = shift;

    my $xml_file = $self->workflow_xml;
    my $fasta_file = $self->pep_file;
    my $chunk_size = $self->chunk_size;
    #print STDERR "\n",$xml_file,"\n";
    #print STDERR "\nfasta file is ",$fasta_file,"\n";
    if(! -f $fasta_file)
    {
        print STDERR "\nwhere is the fasta file ", $fasta_file, "?\n";
        croak "fasta file doesn't exist!";
    }
    my $output = run_workflow_lsf(
                              $xml_file,
                              'fasta file'       => $fasta_file,
                              'chunk size'       => 10,
                              'dev flag'         => 1,
                              'biosql namespace' => 'MGAP',
                              'gram stain'       => 'negative',
                              'report save dir'  => '/gscmnt/temp212/info/annotation/PAP_testing/blast_reports',
    );

    # do quick check on the return value.
    print STDERR Dumper($output),"\n";
    if($output->{'result'} != 1)
    {
        print STDERR "workflow returned an error result, ", 
                     $output->{'result'}, "\n"; 
        return 0;
    }

    return 1;
}

1;

# $Id$
