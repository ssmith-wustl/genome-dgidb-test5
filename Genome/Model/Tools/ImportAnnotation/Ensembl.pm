
package Genome::Model::Tools::ImportAnnotation::Ensembl;

use strict;
use warnings;

use Genome;
use Text::CSV_XS;
use IO::File;
use File::Temp qw/ tempfile /;
use File::Slurp;
use Text::CSV_XS;
use File::Path qw/ mkpath /;
use Carp;

class Genome::Model::Tools::ImportAnnotation::Ensembl {
    is  => 'Command',
    has => [
        outputdir => {
            is  => 'Text',
            doc => "directory to dump annotation files",
        },
        ensembl_version => {
            is  => 'Text',
            doc => "Version of EnsEMBL to use",
        },
        host => {
            is  => 'Text',
            doc => "ensembl db hostname",
        },
        user => {
            is          => 'Text',
            doc         => "ensembl db user name",
            is_optional => 1,
        },
        pass => {
            is          => 'Text',
            doc         => "ensembl db password",
            is_optional => 1,
        },
    ],

#    has_many => [                           # specify the command's multi-value properties (parameters) <---
#        infiles  => { is => 'Text', doc => 'this is a list of values' },
#        outfiles => { is => 'Text', doc => 'also a list of values' },
#    ],
};

sub sub_command_sort_position {12}

sub help_brief
{
    "Import ensembl annotation to the file based data sources";
}

sub help_synopsis
{
    return <<EOS

gt import-annotation ensembl --ensembl-version <ensembl version string> --host <ensembl db hostname> --user <ensembl db user> [--pass <ensembl db password>] --outputdir <directory to dump annotation data>
EOS
}

sub help_detail
{
    return <<EOS
This command is used for importing the ensembl based human annotation data to
the filesystem based data sources.
EOS
}

sub execute
{
    my $self = shift;

    my $outputdir = $self->outputdir;

    # let us see if the outputdir actually exists!
    unless ( -d $outputdir )
    {
        $self->error_message("$outputdir does not exist...\ncreating...");
        eval { mkpath($outputdir); };
        if($@)
        {
            croak;
        }
    }
    my $eversion = $self->ensembl_version_string();

    # the fun abuse of eval is neccessary here to make sure we can do evil
    # things like 'dynamically' load the ensembl modules.
    my $lib = "use lib '/gsc/scripts/share/ensembl-"
        . $eversion
        . "/ensembl/modules';";
    $lib
        .= "\nuse Bio::EnsEMBL::Registry;\nuse Bio::EnsEMBL::DBSQL::DBAdaptor;";
    eval $lib;

    if ($@)
    {
        $self->error_message("not able to load the ensembl modules");
        croak;
    }

    my $reg      = 'Bio::EnsEMBL::Registry';
    my $ens_host = $self->host;
    my $ens_user = $self->user;

    $reg->load_registry_from_db(
        -host => $ens_host,
        -user => $ens_user,
    );

    my $ga = $reg->get_adaptor( 'Human', 'Core', 'Gene' );
    my $ta = $reg->get_adaptor( 'Human', 'Core', 'Transcript' );

    print "gene adaptor: ",       ref($ga), "\n";
    print "transcript adaptor: ", ref($ta), "\n";

    my @xscrpt_ids = @{ $ta->list_dbIDs };
    my $csv        = new Text::CSV_XS( { 'sep_char' => "\t" } );

    my $idx    = 0;
    my $egi_id = 1;    # starting point for external_gene_id...
    my $tss_id = 1;    # starting point for transcript sub struct ids...

    foreach my $trid ( reverse @xscrpt_ids )
    {

        my $tr      = $ta->fetch_by_dbID($trid);
        my $biotype = $tr->biotype();

        my $gene       = $ga->fetch_by_transcript_id( $tr->dbID );
        my $chromosome = $tr->slice()->seq_region_name();

        my ($gene_local_id)  = $gene->stable_id;
        my $transcript_start = $tr->start;
        my $transcript_end   = $tr->end;
        my $strand           = $tr->strand;
        if ( $strand == 1 )
        {
            $strand = "+1";
        }

        my $hugo          = undef;
        my $entrez_id     = undef;
        my $entrez_genest = $tr->get_all_DBLinks('EntrezGene');
        my $entrez_genesg = $gene->get_all_DBLinks('EntrezGene');
        if ( defined(@$entrez_genesg) )
        {
            $hugo      = @$entrez_genesg[0]->display_id;
            $entrez_id = @$entrez_genesg[0]->primary_id;
        }

        $csv->combine( ( $gene->dbID, $hugo, $strand ) );
        write_file(
            $outputdir . "/genes.csv",
            { append => 1 },
            $csv->string() . "\n"
        );

        my @transcript = (
            $tr->dbID,         $gene->dbID,
            $transcript_start, $transcript_end,
            $tr->stable_id,    'ensembl',
            lc( $tr->status ), $strand,
            $chromosome
        );
        $csv->combine(@transcript);
        write_file(
            $outputdir . "/transcripts.csv",
            { append => 1 },
            $csv->string() . "\n"
        );

        my %extids;
        if ( defined($hugo) )
        {
            $extids{hugo_symbol} = $hugo;
        }

        if ( defined($entrez_id) )
        {
            $extids{entrez} = $entrez_id;
        }
        $extids{ensembl} = $gene->stable_id;

        foreach my $type ( sort keys %extids )
        {
            $csv->combine( ( $egi_id, $gene->dbID, $type, $extids{$type} ) );
            write_file(
                $outputdir . "/external_gene_ids.csv",
                { append => 1 },
                $csv->string() . "\n"
            );
            $egi_id++;
        }

        # sub structs
        my @exons = @{ $tr->get_all_Exons() };
        my $ordinal;
        my $phase = 0;
        $ordinal->{'ord'} = ();

        foreach my $exon (@exons)
        {
            my $start    = $exon->coding_region_start($tr);
            my $end      = $exon->coding_region_end($tr);
            my $exon_seq = $exon->seq->seq;
            my $sequence;

            unless ( defined($start) || defined($end) )
            {

               #trss_insert( $tscrpt->transcript_id, "utr_exon", $exon->start,
               #    $exon->end, ordcount( $ordinal, "utrexon" ), $exon_seq );
               #print "1utr_exon", " ", $exon->start, ",",
               #    $exon->end, ":";
                $csv->combine(
                    (   $tss_id,    $tr->dbID,
                        'utr_exon', $exon->start,
                        $exon->end, $self->ordcount( $ordinal, 'utrexon' ),
                        undef,      $exon_seq
                    )
                );
                write_file(
                    $outputdir . "/transcript_sub_structures.csv",
                    { append => 1 },
                    $csv->string() . "\n"
                );
                $tss_id++;
                next;
            }
            if ( $start > $exon->start )
            {
                $sequence = substr( $exon_seq, 0, $start - $exon->start );
                $sequence = substr( $exon_seq, 0 - ( $start - $exon->start ) )
                    if ( $tr->strand == -1 );

                $csv->combine(
                    (   $tss_id,    $tr->dbID,
                        'utr_exon', $exon->start,
                        $exon->end, $self->ordcount( $ordinal, 'utrexon' ),
                        undef,      $exon_seq
                    )
                );

                write_file(
                    $outputdir . "/transcript_sub_structures.csv",
                    { append => 1 },
                    $csv->string() . "\n"
                );
                $tss_id++;

            }

            if ( $end < $exon->end )
            {
                $sequence = substr( $exon_seq, 0 - ( $exon->end - $end ) );
                $sequence = substr( $exon_seq, 0, $exon->end - $end )
                    if ( $tr->strand == -1 );

                $csv->combine(
                    (   $tss_id,    $tr->dbID,
                        'utr_exon', $exon->start,
                        $exon->end, $self->ordcount( $ordinal, 'utrexon' ),
                        undef,      $exon_seq
                    )
                );

                write_file(
                    $outputdir . "/transcript_sub_structures.csv",
                    { append => 1 },
                    $csv->string() . "\n"
                );

                $tss_id++;

            }

            $sequence = substr( $exon_seq, $start - $exon->start,
                $end - $start + 1 );
            $sequence
                = substr( $exon_seq, $exon->end - $end, $end - $start + 1 )
                if ( $tr->strand == -1 );

            #print "   phase different :", $exon->phase, " <>  $phase  ";
            if ( $exon->phase == -1 ) { $exon->phase($phase); }

            $phase = ( $phase + ( $end - $start + 1 ) ) % 3;
            $csv->combine(
                (   $tss_id,    $tr->dbID,
                    'cds_exon', $exon->start,
                    $exon->end, $self->ordcount( $ordinal, 'cdsexon' ),
                    $phase,     $exon_seq
                )
            );
            write_file(
                $outputdir . "/transcript_sub_structures.csv",
                { append => 1 },
                $csv->string() . "\n"
            );

            $tss_id++;
        }

        # introns for transcript sub structures. or not.
        my $translation = $tr->translation();
        if ( defined($translation) )
        {
            $csv->combine( $translation->dbID, $tr->dbID,
                $translation->stable_id, $tr->translate->seq );

            #print $ph $csv->string(),"\n";
            write_file(
                $outputdir . "/proteins.csv",
                { append => 1 },
                $csv->string() . "\n"
            );

        }

    }

    my $splitter = Genome::Model::Tools::ImportAnnotation::SplitFiles->create(
        workdir => $outputdir,
    );
    unless ($splitter){
        $self->error_message("Couldn't create Genome::Model::Tools::ImportAnnotation::SplitFiles to split files in $outputdir");
        die;
    }
    unless ($splitter->execute){
        $self->error_message("Failed to split files in $outputdir!");
        die;
    }

    return 1;
}

sub ensembl_version_string
{
    my $self    = shift;
    my $ensembl = $self->ensembl_version;

    # <ens version>_<ncbi build vers><letter>
    # 52_36n

    my ( $e_version_number, $ncbi_build ) = split( /_/x, $ensembl );
    return $e_version_number;
}

sub ordcount
{
    my $self = shift;
    my $ord  = shift;
    my $type = shift;
    if ( !defined( $ord->{$type} ) )
    {
        $ord->{$type} = 1;
    }
    else
    {
        $ord->{$type}++;
    }
    return $ord->{$type};
}

1;

# $Id$
