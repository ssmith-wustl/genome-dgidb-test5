package Genome::Db::Ensembl::Import::CreateAnnotationStructures;

use strict;
use warnings;

use Genome;

class Genome::Db::Ensembl::Import::CreateAnnotationStructures {
    is  => 'Genome::Db::Ensembl::Import::Base',
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
        data_set => {
            is => 'Text',
            doc => 'Ensembl data set to import',
            default => 'Core',
        },
    ],
};

sub help_brief
{
    "Import ensembl annotation to the file based data sources";
}

sub help_synopsis
{
    return <<EOS

EOS
}

sub help_detail
{
    return <<EOS
EOS
}

sub execute
{
    my $self = shift;
    my $data_set = $self->data_set;

    $self->prepare_for_execution;

    my $registry = $self->connect_registry;
    my $ucfirst_species = ucfirst $self->species;
    my $gene_adaptor = $registry->get_adaptor( $ucfirst_species, $data_set, 'Gene' );
    my $transcript_adaptor = $registry->get_adaptor( $ucfirst_species, $data_set, 'Transcript' );
    my $slice_adaptor = $registry->get_adaptor( $ucfirst_species, $data_set, 'Slice');

    my @slices = @{ $slice_adaptor->fetch_all('toplevel', undef, 1, 0, 1) };

    my $idx = 0;
    my $egi_id = 1;    # starting point for external_gene_id...
    my $tss_id = 1;    # starting point for transcript sub struct ids...

    my $count = 0;
    
    #species, source and version are id properties on all items
    my $source = 'ensembl';
    my $version = $self->version;
    my $species = $self->species;

    #for logging purposes
    my @transcripts;
    my @sub_structures;
    my @proteins;
    my @genes;


    foreach my $slice ( @slices )
    {
        my $chromosome = $slice->seq_region_name();
        my @ensembl_transcripts = @{ $transcript_adaptor->fetch_all_by_Slice($slice)};
        $self->status_message("Importing ".scalar @ensembl_transcripts." transcripts\n");

        foreach my $ensembl_transcript (@ensembl_transcripts) {
            $count++;
            my $biotype = $ensembl_transcript->biotype(); #used in determining rna sub_structures and pseudogene status
            my $ensembl_gene  = $gene_adaptor->fetch_by_transcript_id( $ensembl_transcript->dbID );
            my $ensembl_gene_id = $ensembl_gene->dbID;

            my $transcript_start = $ensembl_transcript->start;
            my $transcript_stop  = $ensembl_transcript->end;

            next unless defined $transcript_start and defined $transcript_stop;

            my $strand = $ensembl_transcript->strand;
            if ( $strand == 1 ) {
                $strand = "+1";
            }
            elsif ($strand == -1) {
                $strand = "-1";
            }
            else {
                $self->warning_message("Invalid strand $strand, skipping!");
            }

            my $hugo_gene_name = undef;
            my $external_db;
            if ($species eq 'human'){
                $external_db = 'HGNC';
            }elsif($species eq 'mouse'){
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
            my $gene_meta = Genome::Gene->__meta__;
            my $composite_gene_id = $gene_meta->resolve_composite_id_from_ordered_values($ensembl_gene_id, $species,$source,$version);
            $gene = Genome::Gene->get(id => $composite_gene_id, data_directory => $self->data_directory);
            unless ($gene){
                $gene = Genome::Gene->create(
                    gene_id => $ensembl_gene_id, 
                    hugo_gene_name => $hugo_gene_name, 
                    strand => $strand,
                    data_directory => $self->data_directory,
                    species => $species,
                    source => $source,
                    version => $version,
                );
                push @genes, $gene;#logging
            }


            #Transcript cols: transcript_id gene_id transcript_start transcript_stop transcript_name source transcript_status strand chrom_name

            my $transcript = Genome::Transcript->create(
                transcript_id => $ensembl_transcript->dbID,
                gene_id => $gene->id,
                gene_name => $gene->name,
                transcript_start => $transcript_start, 
                transcript_stop => $transcript_stop,
                transcript_name => $ensembl_transcript->stable_id,    
                transcript_status => lc( $ensembl_transcript->status ),   #TODO valid statuses (unknown, known, novel) #TODO verify substructures and change status if necessary
                strand => $strand,
                chrom_name => $chromosome,
                data_directory => $self->data_directory,
                species => $species,
                source => $source,
                version => $version,
            );
            push @transcripts, $transcript; #logging

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
                    species => $species,
                    source => $source,
                    version => $version,
                ); 

                $egi_id++;
            }

            #sub structures
            my @ensembl_exons = @{ $ensembl_transcript->get_all_Exons() };

            my @utr_exons;
            my @cds_exons;
            my @rna;

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
                        my $utr_exon = Genome::Db::Ensembl::Import::Base::create_transcript_structure(
                            transcript => $transcript,
                            chrom_name => $transcript->chrom_name,
                            transcript_structure_id => $tss_id,
                            transcript_id => $transcript->transcript_id,
                            structure_type => 'utr_exon',
                            structure_start => $start,
                            structure_stop => $utr_stop,
                            nucleotide_seq => $utr_sequence,
                            data_directory => $self->data_directory,
                            species => $species,
                            source => $source,
                            version => $version,
                        );
                        $tss_id++;
                        push @utr_exons, $utr_exon;
                        push @sub_structures, $utr_exon; #logging
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

                    my $cds_exon = Genome::Db::Ensembl::Import::Base::create_transcript_structure(
                        transcript => $transcript,
                        chrom_name => $transcript->chrom_name,
                        transcript_structure_id => $tss_id,
                        transcript_id => $transcript->transcript_id,
                        structure_type => 'cds_exon',
                        structure_start => $coding_region_start,
                        structure_stop => $coding_region_stop,
                        nucleotide_seq => $cds_sequence,
                        data_directory => $self->data_directory,
                        species => $species,
                        source => $source,
                        version => $version,
                    );

                    $tss_id++;
                    push @cds_exons, $cds_exon;
                    push @sub_structures, $cds_exon; #logging

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

                        my $utr_exon = Genome::Db::Ensembl::Import::Base::create_transcript_structure(
                            transcript => $transcript,
                            chrom_name => $transcript->chrom_name,
                            transcript_structure_id => $tss_id,
                            transcript_id => $transcript->transcript_id,
                            structure_type => 'utr_exon',
                            structure_start => $utr_start,
                            structure_stop => $stop,
                            nucleotide_seq => $utr_sequence,
                            data_directory => $self->data_directory,
                            species => $species,
                            source => $source,
                            version => $version,
                        );
                        $tss_id++;
                        push @utr_exons, $utr_exon;
                        push @sub_structures, $utr_exon; #logging

                    }
                }elsif(defined $coding_region_stop){
                    $self->error_message("ensembl exon has a coding_region_end, but not a coding_region_start!". Dumper $exon);
                    die;
                }else{
                    #no coding region, entire exon is utr. 
                    #create utr exon or rna exon if this transcript biotype is rna
                    my $structure_type = 'utr_exon';
                    if ($biotype =~/RNA/){
                        $structure_type = 'rna';
                    }

                    my $structure = Genome::Db::Ensembl::Import::Base::create_transcript_structure(
                        transcript => $transcript,
                        chrom_name => $transcript->chrom_name,
                        transcript_structure_id => $tss_id,
                        transcript_id => $transcript->transcript_id,
                        structure_type => $structure_type,
                        structure_start => $start,
                        structure_stop => $stop,
                        nucleotide_seq => $exon_sequence,
                        data_directory => $self->data_directory,
                        species => $species,
                        source => $source,
                        version => $version,
                    );

                    push @rna, $structure if $structure_type eq 'rna';
                    push @utr_exons, $structure unless $structure_type eq 'rna';
                    $tss_id++;
                    push @sub_structures, $structure;
                }
            }
            if (@utr_exons > 0 or @cds_exons > 0){
                $self->assign_ordinality_to_exons( $transcript->strand, [@utr_exons, @cds_exons] );
            }
            if (@cds_exons > 0){
                $self->assign_phase( \@cds_exons );
            }

            #create flanks and intron
            my @flanks_and_introns = $self->create_flanking_sub_structures_and_introns($transcript, \$tss_id, [@cds_exons, @utr_exons, @rna]);

            my $protein;
            my $translation = $ensembl_transcript->translation();
            if ( defined($translation) )
            {
                $protein = Genome::Protein->create(
                    protein_id => $translation->dbID,
                    transcript_id => $transcript->id,
                    protein_name => $translation->stable_id,
                    amino_acid_seq => $ensembl_transcript->translate->seq,
                    data_directory => $self->data_directory,
                    species => $species,
                    source => $source,
                    version => $version,
                );
                push @proteins, $protein;
            }

            if ($transcript->cds_full_nucleotide_sequence) {
                my $transcript_seq = Genome::TranscriptCodingSequence->create(
                    transcript_id => $transcript->id,
                    sequence => $transcript->cds_full_nucleotide_sequence,
                    data_directory => $transcript->data_directory,
                );
            }

            # Assign various fields to the transcript
            my %transcript_info;
            $transcript_info{pseudogene} = 0;
            $transcript_info{pseudogene} = 1 if $biotype =~ /pseudogene/;
            if ($biotype =~ /retrotransposed/ and not $transcript->cds_exons) {
                $transcript_info{pseudogene} = 1;
            }
            $self->calculate_transcript_info($transcript, \%transcript_info);

            my @structures = $transcript->sub_structures;
            foreach my $structure (@structures) {
                $self->_update_transcript_info($structure, $transcript);
            }
        }

            $self->write_log_entry($count, \@transcripts, \@sub_structures, \@genes, \@proteins);
            
            #$self->dump_sub_structures(0); #arg added for pre/post commit notation

            $self->status_message( "committing...($count)");
            UR::Context->commit;
            $self->status_message("finished commit!\n");
            
            #$self->dump_sub_structures(1);
 
            Genome::Gene->unload;
            Genome::Transcript->unload;
            Genome::ExternalGeneId->unload;
            Genome::TranscriptStructure->unload;
            Genome::Protein->unload;
            Genome::TranscriptCodingSequence->unload;

            #reset logging arrays
            @transcripts = ();
            @genes = ();
            @proteins = ();
            @sub_structures = ();

            #exit; #uncomment for testing
    }

    return 1;
}

sub _update_transcript_info {
    my $self = shift;
    my $structure = shift;
    my $transcript = shift;

    $structure->transcript_gene_name($transcript->gene_name);
    $structure->transcript_transcript_error($transcript->transcript_error);
    $structure->transcript_coding_region_start($transcript->coding_region_start);
    $structure->transcript_coding_region_stop($transcript->coding_region_stop);
    $structure->transcript_amino_acid_length($transcript->amino_acid_length);

    return 1;
}

sub connect_registry{
    my $self = shift;

    my $lib = "use Bio::EnsEMBL::Registry;\nuse Bio::EnsEMBL::DBSQL::DBAdaptor;";
    eval $lib;

    if ($@)
    {
        $self->error_message("not able to load the ensembl modules");
        croak();
    }

    my $registry = 'Bio::EnsEMBL::Registry';
    my $ens_host = $self->host;
    my $ens_user = $self->user;

    $registry->load_registry_from_db(
        -host => $ens_host,
        -user => $ens_user,
    );
    return $registry;
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
