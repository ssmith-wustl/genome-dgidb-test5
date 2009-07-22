package Genome::Model::Tools::ImportAnnotation::Ensembl;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::ImportAnnotation::Ensembl {
    is  => 'Genome::Model::Tools::ImportAnnotation',
    has => [
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
};

sub sub_command_sort_position {12}

sub help_brief
{
    "Import ensembl annotation to the file based data sources";
}

sub help_synopsis
{
    return <<EOS

gt import-annotation ensembl --version <ensembl version string> --host <ensembl db hostname> --user <ensembl db user> [--pass <ensembl db password>] --output_directory <directory to dump annotation data>
EOS
}

sub help_detail
{
    return <<EOS
This command is used for importing the ensembl based annotation data to the filesystem based data sources.
EOS
}

sub import_objects_from_external_db
{
    my $self = shift;

    $DB::single = 1;
    my $registry = $self->connect_registry;
    my $ucfirst_species = ucfirst $self->species;
    my $gene_adaptor = $registry->get_adaptor( $ucfirst_species, 'Core', 'Gene' );
    my $transcript_adaptor = $registry->get_adaptor( $ucfirst_species, 'Core', 'Transcript' );

    print "gene adaptor: THIS ONE ", ref($gene_adaptor), "\n";
    print "transcript adaptor: ", ref($transcript_adaptor), "\n";

    my @ensembl_transcript_ids = @{ $transcript_adaptor->list_dbIDs };

    my $idx = 0;
    my $egi_id = 1;    # starting point for external_gene_id...
    my $tss_id = 1;    # starting point for transcript sub struct ids...

    my @transcripts;
    my @genes;
    my @proteins;
    my @sub_structures;

    print "Total transcripts: ".scalar @ensembl_transcript_ids."\n";
    my $count = 0;

    foreach my $ensembl_transcript_id ( @ensembl_transcript_ids ) #TODO why reverse here?
    {
        $count++;
        my $ensembl_transcript = $transcript_adaptor->fetch_by_dbID($ensembl_transcript_id);
        #my $biotype = $ensembl_transcript->biotype(); #TODO unused

        my $ensembl_gene  = $gene_adaptor->fetch_by_transcript_id( $ensembl_transcript->dbID );
        my $ensembl_gene_id = $ensembl_gene->dbID;
        my $chromosome = $ensembl_transcript->slice()->seq_region_name();

        my $transcript_start = $ensembl_transcript->start;
        my $transcript_stop  = $ensembl_transcript->end;
        my $strand           = $ensembl_transcript->strand;
        if ( $strand == 1 )
        {
            $strand = "+1";
        }else{
            $strand = "-1";
        }

        my $hugo_gene_name = undef;
        my $external_db;
        if ($self->species eq 'human'){
            $external_db = 'HGNC';
        }elsif($self->species eq 'mouse'){
            $external_db = 'MGI';
        }
        if ($ensembl_gene->external_db =~ /$external_db/){
            $hugo_gene_name = $ensembl_gene->external_name;
        }

        my $entrez_id = undef;
        my $entrez_genes = $ensembl_gene->get_all_DBEntries('EntrezGene');
        if ( defined(@$entrez_genes) )
        {
            $entrez_id = @$entrez_genes[0]->primary_id;
        }

        #gene cols: gene_id hugo_gene_name strand
        my $gene;
        $gene = Genome::Gene->get(gene_id => $ensembl_gene_id, data_directory => $self->data_directory);
        unless ($gene){
            $gene = Genome::Gene->create(
                id => $ensembl_gene_id, 
                hugo_gene_name => $hugo_gene_name, 
                strand => $strand,
                data_directory => $self->data_directory,
            );
        }

        #Transcript cols: transcript_id gene_id transcript_start transcript_stop transcript_name source transcript_status strand chrom_name

        my $transcript = Genome::Transcript->create(
            transcript_id => $ensembl_transcript->dbID,
            gene_id => $gene->id,
            transcript_start => $transcript_start, 
            transcript_stop => $transcript_stop,
            transcript_name => $ensembl_transcript->stable_id,    
            source => 'ensembl',
            transcript_status => lc( $ensembl_transcript->status ),   #TODO valid statuses (unknown, known, novel) #TODO verify substructures and change status if necessary
            strand => $strand,
            chrom_name => $chromosome,
            data_directory => $self->data_directory,
        );

        my %external_gene_ids = $self->get_external_gene_ids($ensembl_gene);
        if ( defined($hugo_gene_name) )
        {
            $external_gene_ids{hugo_symbol} = $hugo_gene_name;
        }

        if ( defined($entrez_id) )
        {
            $external_gene_ids{entrez} = $entrez_id;
        }
        $external_gene_ids{ensembl} = $ensembl_gene->stable_id;

        #external_gene_id columns
        foreach my $type ( sort keys %external_gene_ids )
        {
            my $external_gene_id = Genome::ExternalGeneId->create(
                egi_id => $egi_id,
                gene_id => $gene->id,
                id_type => $type,
                id_value => $external_gene_ids{$type},
                data_directory => $self->data_directory,
            ); 

            $egi_id++;
        }

        #sub structures
        my @ensembl_exons = @{ $ensembl_transcript->get_all_Exons() };

        my @utr_exons;
        my @cds_exons;

        foreach my $exon ( @ensembl_exons )
        #Ensembl exons are combined coding region and untranslated region, we need to create both utr and cds exons from these
        #flank and intron will be created after instantianting these substructures
        #phase and ordinal will be set after instantiating these substructures
        {
            my $coding_region_start = $exon->coding_region_start($ensembl_transcript);
            my $coding_region_stop = $exon->coding_region_end($ensembl_transcript);
            my $start = $exon->start;
            my $stop = $exon->end;
            my $exon_sequence = $exon->seq->seq;

            if (defined $coding_region_start){
                #There is a coding section in this exon
                unless (defined $coding_region_stop){
                    $self->error_message("ensembl exon has a coding_region_start defined, but not a coding_region_end!". Dumper $exon);
                    die;
                }

                if ($coding_region_start > $start){
                    #there is a utr exon between the start of the transcript and the coding region
                    #create utr_exon
                    my $utr_sequence;
                    if ( $transcript->strand eq '+1' ){
                        $utr_sequence = substr( $exon_sequence, 0, $coding_region_start - $start );
                    }
                    else{
                        #sequence is returned stranded, so we need the seq from the end
                        $utr_sequence = substr( $exon_sequence, 0 - ( $coding_region_start - $start ) )
                    }

                    my $utr_stop = $coding_region_start - 1;

                    my $utr_exon = Genome::TranscriptSubStructure->create(
                        transcript_structure_id => $tss_id,
                        transcript => $transcript,
                        structure_type => 'utr_exon',
                        structure_start => $start,
                        structure_stop => $utr_stop,
                        nucleotide_seq => $utr_sequence,
                        data_directory => $self->data_directory,
                    );
                    $tss_id++;
                    push @utr_exons, $utr_exon;
                }

                #create cds_exon (we do a little extra arithmetic here if the whole exon is coding, cleaner this way but could add an alternative block if coding_region_start == start and coding_region_stop == stop)
                my $cds_sequence;
                if ( $transcript->strand eq '+1' ){
                    #grab sequence from start of coding region for length of coding region
                    $cds_sequence = substr( 
                        $exon_sequence, 
                        $coding_region_start - $start,
                        $coding_region_stop - $coding_region_start + 1 );
                }else{
                    #otherwise grab starting at the index of the distance from the coding_region stop to the stop for the length of the coding region
                    $cds_sequence
                    = substr( $exon_sequence, $stop - $coding_region_stop, $coding_region_stop - $coding_region_start + 1 );
                }

                my $cds_exon = Genome::TranscriptSubStructure->create(
                    transcript_structure_id => $tss_id,
                    transcript => $transcript,
                    structure_type => 'cds_exon',
                    structure_start => $coding_region_start,
                    structure_stop => $coding_region_stop,
                    nucleotide_seq => $cds_sequence,
                    data_directory => $self->data_directory,
                );

                $tss_id++;
                push @cds_exons, $cds_exon;

                if ($stop > $coding_region_stop){
                    #there is a utr exon after the coding region
                    #create utr_exon
                    my $utr_sequence;
                    if ( $transcript->strand eq '+1' ){
                        $utr_sequence = substr( $exon_sequence, 0 - ( $stop - $coding_region_stop ) );
                    }else{
                        $utr_sequence = substr( $exon_sequence, 0, $stop - $coding_region_stop )
                    }

                    my $utr_start = $coding_region_stop + 1;

                    my $utr_exon = Genome::TranscriptSubStructure->create(
                        transcript_structure_id => $tss_id,
                        transcript => $transcript,
                        structure_type => 'utr_exon',
                        structure_start => $utr_start,
                        structure_stop => $stop,
                        nucleotide_seq => $utr_sequence,
                        data_directory => $self->data_directory,
                    );
                    $tss_id++;
                    push @utr_exons, $utr_exon;

                }
            }elsif(defined $coding_region_stop){
                $self->error_message("ensembl exon has a coding_region_end, but not a coding_region_start!". Dumper $exon);
                die;
            }else{
                #no coding region, entire exon is utr. 
                #create utr exon
                my $utr_exon = Genome::TranscriptSubStructure->create(
                    transcript_structure_id => $tss_id,
                    transcript => $transcript,
                    structure_type => 'utr_exon',
                    structure_start => $start,
                    structure_stop => $stop,
                    nucleotide_seq => $exon_sequence,
                    data_directory => $self->data_directory,
                );
                $tss_id++;
                push @utr_exons, $utr_exon;
            }
        }
        if (@utr_exons > 0 or @cds_exons > 0){
            $self->assign_ordinality_to_exons( $transcript->strand, [@utr_exons, @cds_exons] );
        }
        if (@cds_exons > 0){
            $self->assign_phase( \@cds_exons );
        }

        #create flanks and intron
        my @flanks_and_introns = $self->create_flanking_sub_structures_and_introns($transcript, \$tss_id, [@cds_exons, @utr_exons]);

        my $protein;
        my $translation = $ensembl_transcript->translation();
        if ( defined($translation) )
        {
            $protein = Genome::Protein->create(
                protein_id => $translation->dbID,
                transcript => $transcript,
                protein_name => $translation->stable_id,
                amino_acid_seq => $ensembl_transcript->translate->seq,
                data_directory => $self->data_directory,
            );
        }

        #double check transcripts here for unknown status

        push @transcripts, $transcript;
        push @genes, $gene;
        push @proteins, $protein if $protein;
        push @sub_structures, (@flanks_and_introns, @cds_exons, @utr_exons);

        unless ($count % 1000){
            #Periodically commit to files so we don't run out of memory
            print "committing...($count)";
            UR::Context->commit;

            print "finished commit!\n";
        }
    }
    return 1;
}

sub connect_registry{
    my $self = shift;
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
        croak();
    }

    my $registry     = 'Bio::EnsEMBL::Registry';
    my $ens_host = $self->host;
    my $ens_user = $self->user;

    $registry->load_registry_from_db(
        -host => $ens_host,
        -user => $ens_user,
    );
    return $registry;
}


sub ensembl_version_string
{
    my $self    = shift;
    my $ensembl = $self->version;

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

sub get_external_gene_ids
{
    my $self = shift;
    my $gene = shift;
    my %external_ids;
    my @entries = @{$gene->get_all_DBEntries()};
    my @dbswanted = qw/ UCSC EntrezGene OTTT CCDS Vega_gene /;
    if ($self->species eq 'human'){
        unshift @dbswanted, (qw/HGNC HGNC_automatic_gene/);
    }elsif ($self->species eq 'mouse'){
        unshift @dbswanted, (qw/MGI MGI_automatic_gene/);
    }
    my %dbs = map { $_ => 1 } @dbswanted; 
    foreach my $entry (@entries)
    {

        my $dbname = $entry->dbname();
        next unless exists($dbs{$dbname});
        my $dbvalue = $entry->display_id();
        $external_ids{$dbname} = $dbvalue;
    }
    return %external_ids;
}


1;

# $Id$
