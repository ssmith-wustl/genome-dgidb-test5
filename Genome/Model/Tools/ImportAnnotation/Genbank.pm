package Genome::Model::Tools::ImportAnnotation::Genbank;

use strict;
use warnings;
use GSC::ImportExport::GenBank;
use GSC::ImportExport::GenBank::Gene;
use GSC::ImportExport::GenBank::Transcript;
use Genome;

use Bio::SeqIO;
use Storable;
use File::Slurp qw/ write_file /;

class Genome::Model::Tools::ImportAnnotation::Genbank {
    is  => 'Genome::Model::Tools::ImportAnnotation',
    has => [
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

gt import-annotation genbank --flatfile <genbank asn1 file> --genbank-file <gb format file of transcripts> --output_directory <output directory> --version <ensembl associated version>
EOS
}

sub help_detail
{
    return <<EOS
This command is used for importing the genbank based annotation data to the filesystem based data sources.
EOS
}


sub import_objects_from_external_db
{
    my $self = shift;

    my $transcript_status;
    if($self->status_file)
    {
        $transcript_status = retrieve $self->status_file;
    }
    else
    {
        $transcript_status = $self->cache_transcript_status();
    }

    $DB::single = 1;

    my $lines;
    foreach my $ts (sort keys %$transcript_status)
    {
        push(@$lines,[$transcript_status->{$ts}->{entrezid}, $transcript_status->{$ts}->{hugo_gene_name}]);  #TODO, possibility this is undef if 'db_xref' tag wasn't present, see above
    }
    


    my $version = $self->version;

    my $gene_id       = 1;
    my $egi_id        = 1;
    my $transcript_id = 1;
    my $protein_id    = 1;
    my $tss_id        = 1;

    my $csv  = Text::CSV_XS->new( { sep_char => "\t" } );
    my $csv1 = Text::CSV_XS->new( { sep_char => "\t" } );

    my $count;
    print scalar @$lines." genes";
    foreach my $record (@$lines)
    {
        $count++;
        my $locus_id = $record->[0];
        my $hugo     = $record->[1]; #TODO this is undefined here?

        # sometimes we get an odd error here, and this hangs, because
        # the bioperl interface way deep in GSC::ImportExport::GenBank::Gene
        # has this odd notion that it wants to rebuild the index, and tries
        # to remove it...  I changed that little bit, so hopefully that won't
        # happen again.
        my $genbank_gene = GSC::ImportExport::GenBank::Gene->retrieve(
            species_name => $self->species,
            version      => $version,
            locus_id     => $locus_id,  #locus id is entrez id
        );

        my @genbank_transcripts = GSC::ImportExport::GenBank::Transcript->retrieve( gene => $genbank_gene);

        my $chromosome = undef;
        {
            if ( $genbank_gene->[0]->{source}->[0]->{subtype}->[0]->{subtype} eq 'chromosome' )  
            {
                $chromosome = $genbank_gene->[0]->{source}->[0]->{subtype}->[0]->{name};
            }
            else
            {
                $self->warning_message("uh oh, no chromosome! setting to UNKNOWN");
                $chromosome = 'UNKNOWN';
            }
        }

        $DB::single = 1;
        my $strand = GSC::ImportExport::GenBank::Gene->resolve_strand(gene=>$genbank_gene);
        $strand = $strand eq '+' ? '+1' : '-1';

        my $external_gene_id = Genome::ExternalGeneId->create(  #TODO, is this necessary
            egi_id => $egi_id,
            gene_id => $gene_id,
            id_type => 'entrez',
            id_value => $locus_id,
            data_directory => $self->data_directory,
        ); 
        $egi_id++;

        my %external_ids = $self->get_external_gene_ids($genbank_gene);
        foreach my $dbname (sort keys %external_ids)
        {
           my $external_gene_id = Genome::ExternalGeneId->create(
               egi_id => $egi_id,
               gene_id => $gene_id,
               id_type => $dbname,
               id_value => $external_ids{$dbname},
               data_directory => $self->data_directory,
               );
           $egi_id++;
        }

        my $gene = Genome::Gene->create(
            id => $gene_id,
            hugo_gene_name => $hugo, 
            strand => $strand,
            data_directory => $self->data_directory,
        );
        $gene_id++;
        
        foreach my $genbank_transcript (@genbank_transcripts) {

            my $transcript_start = undef;
            my $transcript_stop  = undef;
            my $transcript_name  = $genbank_transcript->{accession};
            my $status           = 'unknown';  #this gets filled out later from the status hash
            
            ( $transcript_start, $transcript_stop )
            = $self->transcript_bounds($genbank_transcript);
            unless (defined $transcript_start and defined $transcript_stop){
                next;
            }

            if(exists($transcript_status->{$transcript_name}))
            {
                $status = lc($transcript_status->{$transcript_name}->{status});
            }

            $DB::single = 1;
            my $transcript = Genome::Transcript->create(
                transcript_id => $transcript_id,
                gene_id => $gene->gene_id,
                transcript_start => $transcript_start, 
                transcript_stop => $transcript_stop,
                transcript_name => $transcript_name,
                source => 'genbank',
                transcript_status => $status,   #TODO valid statuses (unknown, known, novel) #TODO verify substructures and change status if necessary
                strand => $strand,
                chrom_name => $chromosome,
                data_directory => $self->data_directory,
            );
            $transcript_id++;
            
            # these give out warnings every once in a while.
            # usually for clone sequences that are associated with a gene
            # ....
            # these both come in sorted
            my @genbank_cds = GSC::ImportExport::GenBank::CDS->retrieve(
                transcript => $genbank_transcript, );
            my @genbank_utr = GSC::ImportExport::GenBank::UTR->convert_to_gsc_params(
                transcript => $genbank_transcript, );

            my @cds_exons;
            my @utr_exons;

            # split out all the exons
            my @seqs;

            foreach my $genbank_exon (@genbank_cds)
            {
                my $structure_start   = $genbank_exon->{from};  #TODO these are different than the below
                my $structure_stop    = $genbank_exon->{to};
                my $cds_sequence = $self->get_seq_slice(  $chromosome, $structure_start, $structure_stop );
                if ( $strand eq "-1" )
                {
                    $cds_sequence = $self->revcom_slice($cds_sequence);
                }
                my $cds_exon = Genome::TranscriptSubStructure->create(
                    transcript_structure_id => $tss_id,
                    transcript => $transcript,
                    structure_type => 'cds_exon',
                    structure_start => $structure_start,
                    structure_stop => $structure_stop,
                    nucleotide_seq => $cds_sequence,
                    data_directory => $self->data_directory,
                );
                $tss_id++;
                push( @seqs, $cds_sequence );
                push @cds_exons, $cds_exon;
            }

            # utr stuff
            foreach my $genbank_exon (@genbank_utr)
            {
                my $structure_start   = $genbank_exon->{begin_position};  #TODO these are different than above
                my $structure_stop    = $genbank_exon->{end_position};
                my $utr_sequence = $self->get_seq_slice( $chromosome, $structure_start, $structure_stop );
                if ( $strand eq "-1" )
                {
                    $utr_sequence = $self->revcom_slice($utr_sequence);
                }

                my $utr_exon = Genome::TranscriptSubStructure->create(
                    transcript_structure_id => $tss_id,
                    transcript => $transcript,
                    structure_type => 'utr_exon',
                    structure_start => $structure_start,
                    structure_stop => $structure_stop,
                    nucleotide_seq => $utr_sequence,
                    data_directory => $self->data_directory,
                );
                $tss_id++;
                push @utr_exons, $utr_exon;

            }
            $DB::single = 1;

            if (@utr_exons > 0 or @cds_exons > 0){
                $self->assign_ordinality_to_exons( $transcript->strand, [@utr_exons, @cds_exons] );
            }
            if (@cds_exons > 0){
                $self->assign_phase( \@cds_exons );
            }

            #create flanks and intron
            my @flanks_and_introns = $self->create_flanking_sub_structures_and_introns($transcript, \$tss_id, [@cds_exons, @utr_exons]);


            my $protein_name = $genbank_transcript->{products}->[0]->{accession};
            # create aa seq, if we're on negative strand, need to reverse the revcomed array of seqs so cds seq is assembled properly for translation
            if ($transcript->strand eq '-1'){
                @seqs = reverse @seqs;
            }
            my $amino_acid_seq = $self->create_protein( \@seqs );

            if ($amino_acid_seq){
                my $protein = Genome::Protein->create(
                    protein_id => $protein_id,
                    transcript => $transcript,
                    protein_name => $protein_name,
                    amino_acid_seq => $amino_acid_seq,
                    data_directory => $self->data_directory,
                );
                $protein_id++;
            }
        }
        unless ($count % 1000){
            #Periodically commit to files so we don't run out of memory
            print "committing...($count)";
            UR::Context->commit;
            print "finished commit!\n";
        }
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
    $DB::single = 1;
    my $self = shift;

    my $seqio = new Bio::SeqIO(
        -file   => $self->genbank_file,
        -format => 'genbank'
    );

    my %ts_status_hash;
    #Check storable status so we don't have to regenerate this file
    my $storable_file = "/gscmnt/sata363/info/medseq/annotation_data/genbank_transcript_status_cache/".$self->species.".".$self->version;

    if (-e $storable_file){
        my $ref = retrieve($storable_file);
        if ($ref){
            return $ref;
        }
    }

    while ( my $seq = $seqio->next_seq() )
    {
        my $annotation = $seq->annotation();
        foreach my $comment ( $annotation->get_Annotations('comment') )
        {
            my ( $status, $junk ) = split( ' ', $comment->text );
            $ts_status_hash{ $seq->display_id }->{status} = lc($status);

        }

        foreach my $feature ( $seq->get_SeqFeatures() )
        {
            if (   ( $feature->primary_tag eq 'gene' )
                && ( $feature->has_tag('db_xref') )
                && ( $feature->has_tag('gene') ) )
            {

                my @values = $feature->get_tag_values('db_xref');
                my ($hugo) = $feature->get_tag_values('gene');
                foreach my $val (@values)
                {
                    if ( $val =~ /GeneID/x )
                    {

                        #TODO if this is always expected to exist, we should handle it
                        # will look like GeneID:144448 or GeneID:(\d+)
                        $val =~ s/GeneID:(\d+)/$1/x;
                        $ts_status_hash{ $seq->display_id }->{entrezid} = $val;
                        $ts_status_hash{ $seq->display_id }->{hugo_gene_name} = $hugo;
                    }
                }

            }

        }
        #return \%ts_status_hash;
    }

    #store this file so we don't have to do it every time
    store \%ts_status_hash, $storable_file;

    return
    \%ts_status_hash;   # should this just be stored in part of the class?
}


#TODO, unused
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


sub revcom_slice
{
    my ( $self, $seq ) = @_;
    my $s = Bio::Seq->new( -display_id => "blah", -seq => $seq );
    return $s->revcom()->seq;
}

sub create_protein
{
    my ( $self, $seq_array) = @_;
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

sub get_external_gene_ids
{
    my ($self,$gene) = @_;
    my %external_ids;
    if( exists($gene->[0]->{gene}->[0]->{db}) )
    {
        foreach my $external ( @{$gene->[0]->{gene}->[0]->{db}} )
        {
            my $dbname = $external->{db};
            my $dbvalue = $external->{tag}->[0]->{id} || $external->{tag}->[0]->{str};
            $external_ids{$dbname} = $dbvalue;
        }
    }
    return %external_ids;
}

sub get_seq_slice
{
    my ( $self, $chrom, $start, $stop ) = @_;
    my $slice = undef;
    my $reference_build = $self->reference_build;

    my $file = $reference_build->get_bases_file($chrom);
    $slice = $reference_build->sequence( $file, $start, $stop );
    return $slice;
}

sub reference_build
{
    my $self = shift;
    unless ($self->{reference_build}){
        my $species = $self->species;
        my ($reference_build_version) = $self->version =~ /^\d+_(\d+)[a-z]$/; #currently only supports versions in familiar formats(54_36p, 54_37g) possible these will get more complicated later
        my $build = Genome::Model->get(name => "NCBI-$species")->build_by_version($reference_build_version);
        unless ($build){
            $self->error_message("Couldn't find reference sequence build version $reference_build_version for species $species");
            die;
        }
        $self->{reference_build} = $build;
    }
    return $self->{reference_build};
}

1;

# $Id$
