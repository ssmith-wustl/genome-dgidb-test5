package Genome::Model::Tools::ImportAnnotation::Genbank;

use strict;
use warnings;
use GSC::ImportExport::GenBank;
use GSC::ImportExport::GenBank::Gene;
use GSC::ImportExport::GenBank::Transcript;
use Genome;

use Bio::SeqIO;
use File::Slurp;
use File::Temp qw/ tempfile /;
use File::Path;
use Text::CSV_XS;
use Carp;
use Storable;

class Genome::Model::Tools::ImportAnnotation::Genbank {
    is  => 'Command',
    has => [
        outputdir => {
            is  => 'Text',
            doc => "directory to dump annotation files",
        },
        version => {
            is  => 'Text',
            doc => "Version to use",
        },
        flatfile => {
            is  => 'Text',
            doc => "path to asn.1 flat file",
        },
        genbank_file => {
            is  => 'Text',
            doc => "path to genbank format file",
        },
        status_file => {
            is => 'Text',
            doc => "path to storable hash of transcript statuses",
            is_optional => 1,
        },

    ],
};


sub sub_command_sort_position {12}

sub help_brief
{
    "Import genbank annotation to the file based data sources";
}

sub help_synopsis
{
    return <<EOS

gt import-annotation genbank --flatfile <genbank asn1 file> --genbank-file <gb format file of transcripts> --outputdir <output directory> --version <ensembl associated version>
EOS
}

sub help_detail
{
    return <<EOS
This command is used for importing the genbank based human annotation data to
the filesystem based data sources.
EOS
}


sub execute
{
    my $self = shift;
    unless( -d $self->outputdir )
    {
        eval { mkpath( $self->outputdir ); };
        if($@)
        {
            $self->error_msg("can't create outputdir path\n$@");
            exit 1;
        }
    }


    my $status_hash;
    if($self->status_file)
    {
        $status_hash = retrieve $self->status_file;
    }
    else
    {
        $status_hash = $self->cache_transcript_status();
    }
    #store $status_hash, 'status_hash.stor';
    #exit;

    $self->get_from_flatfile($status_hash);
    
    my $outputdir = $self->outputdir;
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

# need to grab the genbank format rna file  (status, maybe peptides)
# start going thru the asn.1 flat file...
#
#

# read asn.1 file for all the genes, transcripts, tss's, protein names,
# start going thru genbank flat file for transcript statuses (could do
# before or after?)

sub cache_transcript_status
{
    my $self = shift;

    my $seqio = new Bio::SeqIO(
        -file   => $self->genbank_file,
        -format => 'genbank'
    );

    my %ts_status_hash;

    while ( my $seq = $seqio->next_seq() )
    {
        my $a = $seq->annotation();
        foreach my $comment ( $a->get_Annotations('comment') )
        {
            my ( $status, $junk ) = split( / /, $comment->text );
            $ts_status_hash{ $seq->display_id }->{status} = lc($status);

        }

        foreach my $feat ( $seq->get_SeqFeatures() )
        {
            if (   ( $feat->primary_tag eq 'gene' )
                && ( $feat->has_tag('db_xref') ) )
            {

                my @values = $feat->get_tag_values('db_xref');
                foreach my $val (@values)
                {
                    if ( $val =~ /GeneID/x )
                    {

                        # will look like GeneID:144448 or GeneID:(\d+)
                        $val =~ s/GeneID:(\d+)/$1/x;
                        $ts_status_hash{ $seq->display_id }->{entrezid}
                            = $val;
                    }
                }

            }

        }
        #return \%ts_status_hash;
    }

    return
        \%ts_status_hash;   # should this just be stored in part of the class?
}

sub get_from_flatfile
{
    my $self        = shift;
    my $status_href = shift;
    my $dir         = $self->outputdir;
    #print STDERR "before getting llids\n";
    #my $lines       = $self->get_llids_hugo_names();
    my $lines;
    foreach my $ts (sort keys %$status_href)
    {
        push(@$lines,$status_href->{$ts}->{entrezid});
    }
    
    #print STDERR "got ", $#{$lines}," ids\n";
    #should we use this as an option?
    my $model = Genome::Model::ImportedReferenceSequence->get(2741951221);
    my $build = $model->build_by_version(36);


    my $version = $self->version;

    my $gene_id       = 1;
    my $egi_id        = 1;
    my $transcript_id = 1;
    my $protein_id    = 1;
    my $tss_id        = 1;

    my $csv  = Text::CSV_XS->new( { sep_char => "\t" } );
    my $csv1 = Text::CSV_XS->new( { sep_char => "\t" } );
    $DB::single = 1;
    foreach my $rec (@$lines)
    {
        $csv->parse($rec);
        my @f        = $csv->fields();
        my $locus_id = $f[0];
        my $hugo     = $f[1];

        # sometimes we get an odd error here, and this hangs, because
        # the bioperl interface way deep in GSC::ImportExport::GenBank::Gene
        # has this odd notion that it wants to rebuild the index, and tries
        # to remove it...  I changed that little bit, so hopefully that won't
        # happen again.
        my $gene = GSC::ImportExport::GenBank::Gene->retrieve(
            species_name => 'human',
            version      => $version,
            locus_id     => $locus_id,
        );

        my @tr
            = GSC::ImportExport::GenBank::Transcript->retrieve( gene => $gene,
            );

        my $chromosome = undef;
        {
            if ( $gene->[0]->{source}->[0]->{subtype}->[0]->{subtype} eq
                'chromosome' )
            {
                $chromosome
                    = $gene->[0]->{source}->[0]->{subtype}->[0]->{name};
            }
            else
            {
                carp "uh oh, on chromosome!";
            }
        }

        my $strand = undef;

        foreach my $transcript (@tr)
        {

            my $transcript_start = undef;
            my $transcript_stop  = undef;
            my $transcript_name  = $transcript->{accession};
            my $source           = 'genbank';                  # genbank???
            my $status           = 'unknown';
            # these give out warnings every once in a while.
            # usually for clone sequences that are associated with a gene
            # ....
            my @cds = GSC::ImportExport::GenBank::CDS->retrieve(
                transcript => $transcript, );
            my @utr = GSC::ImportExport::GenBank::UTR->convert_to_gsc_params(
                transcript => $transcript, );


            if ( !defined($strand) )
            {
                $strand = $transcript->{'genomic-coords'}->[0]->{mix}->[0]
                    ->{'int'}->[0]->{strand};
                $strand = ( $strand eq 'plus' ) ? '+1' : '-1';

            }

            # split out all the exons
            my $ordinal = 1;
            my @seqs;
            if ( $strand eq "-1" )
            {
                @cds = reverse @cds;
            }

            foreach my $exon (@cds)
            {
                my $structure_type = "cds_exon";
                my $struct_start   = $exon->{from};
                my $struct_stop    = $exon->{to};
                my $seq = $self->get_seq_slice( $build, $chromosome,
                    $struct_start, $struct_stop );
                if ( $strand eq "-1" )
                {
                    $seq = $self->revcom_slice($seq);
                }
                my $phase = 0;
                my $length = $struct_stop - $struct_start + 1;
                $phase = ($phase+$length) % 3;
                my @tss = (
                    $tss_id, $transcript_id, $structure_type, $struct_start,
                    $struct_stop, $ordinal, $phase, $seq
                );
                $csv1->combine(@tss);
                write_file(
                    $dir . "/transcript_sub_structures.csv",
                    { append => 1 },
                    $csv1->string() . "\n"
                );
                $ordinal++;
                $tss_id++;
                push( @seqs, $seq );
            }

            my $i = 1;
            $ordinal = 1;

            # calculate introns
            while ( $i <= $#cds )
            {
                my @intron = (
                    $tss_id, $transcript_id, 'intron',
                    $cds[ $i - 1 ]->{to} + 1,
                    $cds[$i]->{from} - 1,
                    $ordinal, undef, undef
                );
                $csv1->combine(@intron);
                write_file(
                    $dir . "/transcript_sub_structures.csv",
                    { append => 1 },
                    $csv1->string() . "\n"
                );
                $i++;
                $ordinal++;
            }

            # utr stuff
            $ordinal = 1;
            foreach my $exon (@utr)
            {
                my $structure_type = "utr_exon";
                my $struct_start   = $exon->{begin_position};
                my $struct_stop    = $exon->{end_position};
                my $seq = $self->get_seq_slice( $build, $chromosome,
                    $struct_start, $struct_stop );
                my $phase = 0;

                my @tss = (
                    $tss_id, $transcript_id, $structure_type, $struct_start,
                    $struct_stop, $ordinal, $phase, $seq
                );
                $csv1->combine(@tss);
                write_file(
                    $dir . "/transcript_sub_structures.csv",
                    { append => 1 },
                    $csv1->string() . "\n"
                );
                $ordinal++;
                $tss_id++;

            }

            ( $transcript_start, $transcript_stop )
                = $self->transcript_bounds($transcript);
            $csv1->combine(
                $tss_id, $transcript_id, "flank",
                $transcript_start - 50000,
                $transcript_start - 1,
                1, 0, undef
            );
            write_file(
                $dir . "/transcript_sub_structures.csv",
                { append => 1 },
                $csv1->string() . "\n"
            );
            $tss_id++;
            $csv1->combine(
                $tss_id, $transcript_id, "flank",
                $transcript_stop + 1,
                $transcript_stop + 50000,
                2, 0, undef
            );
            write_file(
                $dir . "/transcript_sub_structures.csv",
                { append => 1 },
                $csv1->string() . "\n"
            );
            $tss_id++;

            if(exists($status_href->{$transcript_name}))
            {
                $status = lc($status_href->{$transcript_name}->{status});
            }

            my @transcriptinfo = (
                $transcript_id,   $gene_id,         $transcript_start,
                $transcript_stop, $transcript_name, $source,
                $status,          $strand,          $chromosome
            );
            $csv1->combine(@transcriptinfo);
            write_file(
                $dir . "/transcripts.csv",
                { append => 1 },
                $csv1->string() . "\n"
            );
            $transcript_id++;
            my $protein_name = $transcript->{products}->[0]->{accession};

            my $amino_acid_seq
                = $self->create_protein( \@seqs );    # create aa seq
            my @protein_info = (
                $protein_id,   $transcript_id,
                $protein_name, $amino_acid_seq
            );
            $csv1->combine(@protein_info);
            write_file(
                $dir . "/proteins.csv",
                { append => 1 },
                $csv1->string() . "\n"
            );
            $protein_id++;
        }

        my @egi = ( $egi_id, $gene_id, "entrez", $locus_id );
        $csv1->combine(@egi);
        write_file(
            $dir . "/external_gene_ids.csv",
            { append => 1 },
            $csv1->string() . "\n"
        );
        $egi_id++;
        $csv1->combine( $gene_id, $hugo, $strand );
        write_file(
            $dir . "/genes.csv",
            { append => 1 },
            $csv1->string() . "\n"
        );
        $gene_id++;

    }

    return 1;
}

sub get_llids_hugo_names
{
    my $self = shift;
    my $file = $self->flatfile;

    my ( $oh, $output ) = tempfile( "llids_hugos_XXXXXX", SUFFIX => '.dat' );
    my $seqio = Bio::SeqIO->new(
        -file   => $file,
        -format => 'entrezgene',
    );
    my @lines = ();
    # this is excrutiatingly long, need to check that most things don't change
    # from release to release...  possibly the biggest time sink!
    while ( my $result = $seqio->next_seq )
    {
        my $entrezid = $result->accession_number();
        my $hugoname = $result->id();
        if(!defined($hugoname))
        {
            $hugoname = "";
        }

        push( @lines, $entrezid . "\t" . $hugoname . "\n" );

        #return \@lines; # temp, remove
    }



    return \@lines;    # or @lines?
}

sub transcript_bounds
{
    my ( $self, $transcript ) = @_;

    # go thru the exons here to get the start and stop.
    my @exons = GSC::ImportExport::GenBank::Exon->retrieve(
        transcript => $transcript );
    my $strand = undef;
    my $max    = undef;
    my $min    = undef;
    foreach my $e (@exons)
    {
        #unfun
        if ( !defined($min) || ( $min > $e->{from} ) )
        {
            $min = $e->{from};
        }

        if ( !defined($max) || ( $max < $e->{to} ) )
        {
            $max = $e->{to};
        }
    }

    return ( $min, $max );
}

sub get_seq_slice
{
    my ( $self, $build, $chrom, $start, $stop ) = @_;
    my $slice = undef;


    my $file = $build->get_bases_file($chrom);
    $slice = $build->sequence( $file, $start, $stop );
    return $slice;
}

sub revcom_slice
{
    my ( $self, $seq ) = @_;
    my $s = Bio::Seq->new( -display_id => "blah", -seq => $seq );
    return $s->revcom()->seq;
}

sub create_protein
{
    my ( $self, $seq_array ) = @_;
    my @sequence = @$seq_array;

    my $transcript = join( "", @sequence );
    if(($transcript eq "") ||
       (!defined($transcript)))
    {
        return undef; # Bio::Seq throws an annoying warning otherwise
    }
    my $tran = Bio::Seq->new(
        -display_id => "blah",
        -seq        => $transcript,
    );
    my $aa = $tran->translate()->seq();
    return $aa;
}

1;

# $Id$
