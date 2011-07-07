package Genome::Model::Tools::ImportAnnotation::Genbank;

use strict;
use warnings;
use Genome;
use Carp;

use Bio::SeqIO;
use Storable;
use File::Slurp qw/ write_file /;
use File::Basename qw/ fileparse /;
use Storable qw/ nstore dclone /;
use Devel::StackTrace;

class Genome::Model::Tools::ImportAnnotation::Genbank {
    is  => 'Genome::Model::Tools::ImportAnnotation',
    has => [
        flatfile => {
            is  => 'Path',
            is_input => 1,
            doc => 'Path to the .agc genbank flat file',
        },
        genbank_file => {
            is  => 'Path',
            is_input => 1,
            doc => 'Path to the .gbff genbank file',
        },
        idx_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Path to the genbank idx index file',
        },
        status_file => {
            is => 'Text',
            is_input => 1,
            doc => "path to storable hash of transcript statuses",
            is_optional => 1,
        },
    ],
    has_optional => [
        idx => {
            is => 'Bio::ASN1::EntrezGene::Indexer',
            is_input => 0,
            doc => 'We are stashing this objectified idx file to speed this up...',
        },
        reference_id => { 
            is => 'NUMBER', 
            is_input => 1, 
            doc => 'Reference sequence build to use for sequence lookups' 
        },
        reference_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence', 
            id_by => 'reference_id' 
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


sub execute {
    my $self = shift;
    $self->prepare_for_execution;

    # If the index file does not exist, we need to generate one
    unless (-e $self->idx_file) {
        $self->generate_idx_file;
    }

    # UR::Context->create_subscription(
        # method => 'commit',
        # callback => sub { print Devel::StackTrace->new(no_refs => 1)->as_string });

    my $transcript_status;
    if($self->status_file)
    {
        $transcript_status = retrieve $self->status_file;
    }
    else
    {
        $transcript_status = $self->cache_transcript_status();
    }

    my $lines;
    foreach my $ts (sort keys %$transcript_status)
    {
        push(@$lines,[$transcript_status->{$ts}->{entrezid}, $transcript_status->{$ts}->{hugo_gene_name}, $transcript_status->{$ts}->{transcript_version}]);  
    }
    
    #dedup hash based on locus_id
    my %seen;
    my @unique_lines = grep {!$seen{@$_[0]}++} @$lines;

    my $gene_id       = 1;
    my $egi_id        = 1;
    my $transcript_id = 1;
    my $protein_id    = 1;
    my $tss_id        = 1;

    my $count = 0;
    my $current_thousand = 0;  #since genbank is imported per gene, 
                               #we use this to commit roughly every thousand instead of exactly
    $self->status_message("importing ". scalar @$lines. " transcripts");

    #species, source and version are id properties on all items
    my $source = 'genbank';
    my $version = $self->version;
    my $species = $self->species;

    # Grab sequence id using species name
    my $taxon = Genome::Taxon->get(species_name => $species);
    confess "Could not get taxon for $species" unless $taxon;
    my $seq_id = $taxon->current_genome_refseq_id;
    confess "Could not get refseq id from taxon" unless defined $seq_id;

    #for logging purposes
    my @transcripts;
    my @sub_structures;
    my @proteins;
    my @genes;

    $self->set_reference_build unless $self->reference_build; #use this crappy logic if we don't have a ref seq. specified
    if (Genome::DataSource::GMSchema->has_default_handle) {
        $self->status_message("Disconnecting GMSchema default handle.");
        Genome::DataSource::GMSchema->disconnect_default_dbh();
    }
    my $idx = $self->get_idx_file;
    $self->idx($idx); 
    

    RECORD: foreach my $record (@unique_lines)
    {
        my $locus_id = $record->[0];
        my $hugo     = $record->[1]; 
        my $transcript_version = $record->[2];

        # sometimes we get an odd error here, and this hangs, because
        # the bioperl interface way deep in GSC::ImportExport::GenBank::Gene
        # has this odd notion that it wants to rebuild the index, and tries
        # to remove it...  I changed that little bit, so hopefully that won't
        # happen again.
        my $genbank_gene = $self->retrieve_gene($locus_id); 
        unless ($genbank_gene) {
            if($hugo =~ '^LOC'){ #Genes with this prefix are predicted and probably don't exist.  Mike's having us omit them for the time being
                $self->status_message("Could not retrieve predicted gene with ID $locus_id.  Skipping to next gene");
                next RECORD;
            }
            else{
                $self->error_message("Could not retrieve gene with ID $locus_id, exiting!");
                croak;
            }
        }

        my $is_pseudogene = $self->is_pseudogene($genbank_gene);

        my @genbank_transcripts = $self->retrieve_transcripts($genbank_gene);

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

        my $strand = $self->resolve_strand($genbank_gene);
        unless($strand eq '+1' or $strand eq '-1'){
            $self->warning_message("Invalid strand $strand, not importing");
            next RECORD;
        }

        my $gene = Genome::Gene->create(
            gene_id => $gene_id,
            hugo_gene_name => $hugo, 
            strand => $strand,
            data_directory => $self->data_directory,
            species => $species,
            source => $source,
            version => $version,
        );
        $gene_id++;
        push @genes, $gene; #logging
        
        my $external_gene_id = Genome::ExternalGeneId->create(  
            egi_id => $egi_id,
            gene_id => $gene->id,
            id_type => 'entrez',
            id_value => $locus_id,
            data_directory => $self->data_directory,
            species => $species,
            source => $source,
            version => $version,
        ); 
        $egi_id++;

        my %external_ids = $self->get_external_gene_ids($genbank_gene);
        foreach my $dbname (sort keys %external_ids)
        {
           my $external_gene_id = Genome::ExternalGeneId->create(
               egi_id => $egi_id,
               gene_id => $gene->id,
               id_type => $dbname,
               id_value => $external_ids{$dbname},
               data_directory => $self->data_directory,
               species => $species,
               source => $source,
               version => $version,
               );
           $egi_id++;
        }
        
        foreach my $genbank_transcript (@genbank_transcripts) {

            $count++;
            my $transcript_start = undef;
            my $transcript_stop  = undef;
            my $transcript_name  = $genbank_transcript->{accession}; 
            my $status           = 'unknown';  #this gets filled out later from the status hash

            ($transcript_start, $transcript_stop)
                = $self->transcript_bounds($genbank_transcript);
            unless (defined $transcript_start and defined $transcript_stop){
                next;
            }

            if(exists($transcript_status->{$transcript_name}))
            {
                $status = lc($transcript_status->{$transcript_name}->{status});
            }
            
            next if $status eq 'unknown';
            
            my $rna_transcript = $self->is_rna($genbank_gene);
            $rna_transcript = 1 if $transcript_name =~ /^[NX]R/;
            
            my $transcript = Genome::Transcript->create(
                transcript_id => $transcript_id,
                gene_id => $gene->id,
                gene_name => $gene->name,
                transcript_start => $transcript_start, 
                transcript_stop => $transcript_stop,
                transcript_name => join('.', $transcript_name, $transcript_version), #We are now going to store transcript names as transcript_name.version.  Make it so
                transcript_status => $status,
                strand => $strand,
                chrom_name => $chromosome,
                data_directory => $self->data_directory,
                species => $species,
                source => $source,
                version => $version,
            );
            $transcript_id++;
            push @transcripts,$transcript; #logging;
            
            # these give out warnings every once in a while.
            # usually for clone sequences that are associated with a gene
            # ....
            # these both come in sorted
            my @genbank_cds = $self->retrieve_CDS($genbank_transcript);
            my @genbank_utr = $self->retrieve_UTR($genbank_transcript);

            my @cds_exons;
            my @utr_exons;
            my @rna;

            # split out all the exons
            my @seqs;

            foreach my $genbank_exon (@genbank_cds)
            {
                my $structure_start   = $genbank_exon->{from};  #TODO these are different than the below
                my $structure_stop    = $genbank_exon->{to};
                my $cds_sequence = $self->get_seq_slice(  $chromosome, $structure_start, $structure_stop );
                if ( $strand eq "-1" )
                {
                    unless ($cds_sequence) {
                        $self->warning_message("Attempted to reverse complement empty sequence string!");
                        $self->warning_message("Sequence originated from chromosome $chromosome between " .
                            " positions $structure_start and $structure_stop for transcript " .
                            $transcript->transcript_name . " and structure $tss_id");
                    }
                    else {
                        $cds_sequence = $self->revcom_slice($cds_sequence);
                    }
                }
                my $cds_exon = Genome::TranscriptSubStructure->create(
                    transcript_structure_id => $tss_id,
                    transcript => $transcript,
                    structure_type => 'cds_exon',
                    structure_start => $structure_start,
                    structure_stop => $structure_stop,
                    nucleotide_seq => $cds_sequence,
                    data_directory => $self->data_directory,
                    species => $species,
                    source => $source,
                    version => $version,
                );
                $tss_id++;
                push( @seqs, $cds_sequence );
                push @cds_exons, $cds_exon;
                push @sub_structures, $cds_exon; #logging
            }

            # utr stuff
            foreach my $genbank_exon (@genbank_utr)
            {
                my $structure_type = 'utr_exon';
                $structure_type = 'rna' if $rna_transcript;

                my $structure_start   = $genbank_exon->{begin_position};  #TODO these are different than above
                my $structure_stop    = $genbank_exon->{end_position};

                my $sequence = $self->get_seq_slice( $chromosome, $structure_start, $structure_stop );
                if ($strand eq '-1') {
                    unless ($sequence) {
                        $self->warning_message("Attempted to reverse complement empty sequence string!");
                        $self->warning_message("Sequence originated from chromosome $chromosome between " .
                            " positions $structure_start and $structure_stop for transcript " .
                            $transcript->transcript_name . " and structure $tss_id");
                    }
                    else {
                        $sequence = $self->revcom_slice($sequence);
                    }
                }

                my $structure = Genome::TranscriptSubStructure->create(
                    transcript_structure_id => $tss_id,
                    transcript => $transcript,
                    structure_type => $structure_type,
                    structure_start => $structure_start,
                    structure_stop => $structure_stop,
                    nucleotide_seq => $sequence,
                    data_directory => $self->data_directory,
                    species => $species,
                    source => $source,
                    version => $version,
                );
                $tss_id++;
                push @utr_exons, $structure if $structure_type eq 'utr_exon';
                push @rna, $structure if $structure_type eq 'rna';
                push @sub_structures, $structure; #logging
            }

            if (@utr_exons > 0 or @cds_exons > 0){
                $self->assign_ordinality_to_exons( $transcript->strand, [@utr_exons, @cds_exons] );
            }
            if (@cds_exons > 0){
                $self->assign_phase( \@cds_exons );
            }

            #create flanks and intron
            my @flanks_and_introns = $self->create_flanking_sub_structures_and_introns(
                $transcript, \$tss_id, [@cds_exons, @utr_exons, @rna]
            );

            my $protein_name = $genbank_transcript->{products}->[0]->{accession};
            # create aa seq, if we're on negative strand, need to reverse the revcomed array of seqs
            # so cds seq is assembled properly for translation
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
                    species => $species,
                    source => $source,
                    version => $version,
                );
                $protein_id++;
                push @proteins, $protein;
            }

            if ($transcript->cds_full_nucleotide_sequence) {
                my $transcript_seq = Genome::TranscriptCodingSequence->create(
                    transcript_id => $transcript->id,
                    sequence => $transcript->cds_full_nucleotide_sequence,
                    data_directory => $transcript->data_directory,
                );
            }
            
            # Assign various fields of the transcript
            my %transcript_info;
            $transcript_info{pseudogene} = $is_pseudogene;
            $transcript_info{rna} = $rna_transcript;
            $self->calculate_transcript_info($transcript, \%transcript_info);
        }

        # Periodically commit to files so we don't run out of memory
        #if (int($count/1000) >  $current_thousand){
        if (int($count/10) >  $current_thousand){
            $current_thousand = int($count/1000);
            $self->write_log_entry($count, \@transcripts, \@sub_structures, \@genes, \@proteins);

            $self->dump_sub_structures(0); #arg added for pre/post commit notation

            $self->status_message("I have a DBH pre-commit, I probably shouldn't") if Genome::DataSource::GMSchema->has_default_dbh;
            $self->status_message( "committing...($count)");
            UR::Context->commit;
            $self->status_message("finished commit!");
            $self->status_message("I have a DBH, I probably shouldn't") if Genome::DataSource::GMSchema->has_default_dbh;
            
            $self->dump_sub_structures(1);
            
            #reset logging arrays
            @transcripts = ();
            @genes = ();
            @proteins = ();
            @sub_structures = ();

            #return 1; #uncomment for testing
        }
    }
    $self->status_message("committing...($count)");
    UR::Context->commit;
    $self->status_message("finished commit!");
    $self->status_message("Import complete");

    return 1;
}

# need to grab the genbank format rna file  (status, maybe peptides)
# start going thru the asn.1 flat file...

# read asn.1 file for all the genes, transcripts, tss's, protein names,
# start going thru genbank flat file for transcript statuses (could do
# before or after?)
sub retrieve_gene {
    my ($self, $locus_id) = @_;
    my $idx = $self->idx;
    my $gene = $idx->fetch_hash($locus_id);
    unless ($gene) {
        $self->error_message("Failed to fetch gene with locus ID $locus_id");
        return;
    }
    return $gene;
}

sub get_idx_file {
    my $self = shift;
    my $idx_file = $self->idx_file;

    my $idx;
    if (-e $idx_file) {
        my $rv = eval { $idx = Bio::ASN1::EntrezGene::Indexer->new(-filename => $idx_file) };
        if (!$rv or $@) {
            unlink($idx_file);
            return $self->generate_idx_file;
        }
        return $idx;
    }
    else {
        return $self->generate_idx_file;
    }

    return $idx;
}

sub generate_idx_file {
    my $self = shift;
    my $idx_file = $self->idx_file;
    my $agc_file = $self->flatfile;
    my ($name, $path) = fileparse($agc_file);
    my $name_without_suffix = substr($name, 0, rindex($name, "."));

    my $idx = Bio::ASN1::EntrezGene::Indexer->new(
        -filename => "$path/$name_without_suffix.idx",
        -write_flag => 'WRITE'
    );
    $idx->make_index($agc_file);
    return $idx
}

sub is_pseudogene {
    my ($self, $gene) = @_;
    if ($gene->[0]->{type} =~ /pseudo/) {
        return 1;
    }
    return 0;
}

sub is_rna{
    my ($self, $gene) = @_;
    if ($gene->[0]->{gene}->[0]->{desc} =~ /non-protein coding/) {
        return 1;
    }

    if ($gene->[0]->{type} =~ /RNA/) {
        return 1;
    }

    return 0;
}

sub resolve_strand {
    my ($self, $gene) = @_;
    unless ($gene && ref $gene eq 'ARRAY') {
        $self->error_message("resolve_strand needs an NCBI gene object");
        return;
    }

    my @transcripts  = $self->retrieve_transcripts($gene); 
    return unless @transcripts;

    my @exons = $self->retrieve_exons($transcripts[0]);
    return unless @exons;

    return $exons[0]->{strand} eq 'plus' ? '+1' : '-1';
}

sub retrieve_exons{
    my ($self, $transcript) = @_;
    unless ($transcript){
        $self->error_message("No transcript specified, exiting");
        return;
    }

    my $acc = $transcript->{accession};
    my @exons = ();
    if (exists($transcript->{'genomic-coords'}->[0]->{int})) {
        @exons = @{ dclone($transcript->{'genomic-coords'}->[0]->{int}) };
    }
    elsif (exists($transcript->{'genomic-coords'}->[0]->{mix}->[0]->{int})) {
        @exons = @{ dclone($transcript->{'genomic-coords'}->[0]->{mix}->[0]->{int}) };
    }
    else {
        $self->error_message('mRNA ' . $acc . ' has no exons!');
        return;
    }
    
    ## GenBank seems to start couting at 0, but GFF counts from 1
    foreach my $e (@exons) {
        ( $e->{from}, $e->{to} ) = map  { $_ + 1 }    ( $e->{from}, $e->{to} );
    }
    return $self->sort_tags(\@exons, 'from', 'to');
}

sub sort_tags{
    my ($self, $tags_ref, $start, $end) = @_;
    my @tags = @$tags_ref;
    unless (@tags){
        $self->error_message("No exons, exiting");
        return;
    }

    # default the keys to 'start' and 'end' if not provided
    $start = 'start' unless (defined $start);
    $end   = 'end'   unless (defined $end);

    # sort
    foreach my $t (@tags) {
    # make sure all start coords are less than the corresponding end coord
        ($t->{$start}, $t->{$end}) = sort { $a <=> $b } ($t->{$start}, $t->{$end});
    }
    # then sort the entire list by start coordinate
    @tags = sort { $a->{$start} <=> $b->{$start} } @tags;

    return @tags;
}

sub retrieve_CDS{
    my ($self, $transcript) = @_;
    unless ($transcript){
        $self->error_message("No transcript specified, exiting");
        return;
    }

    my $acc = $transcript->{accession};
         
    my @cds = ();
    unless (exists($transcript->{products})) {
        warn ("Found no CDS info in magic genbank hash!");
        return;
    }

    my $protein = @{ $transcript->{products} }[0];

    if ( exists( $protein->{'genomic-coords'}->[0]->{int} ) ) {
        @cds = @{ dclone( $protein->{'genomic-coords'}->[0]->{int} ) };
    }  
    elsif ( exists( $protein->{'genomic-coords'}->[0]->{'packed-int'} ) ) {
        @cds = @{ dclone( $protein->{'genomic-coords'}->[0]->{'packed-int'} ) };
    }
    elsif (exists( $protein->{'genomic-coords'}->[0]->{mix}->[0]->{int} ) ) {
        @cds = @{ dclone( $protein->{'genomic-coords'}->[0]->{mix}->[0]->{int} ) };
    } 


    unless (@cds) {
        warn ("Found no CDS info in magic genbank hash!");
    return;
    }

    ## GenBank seems to start couting at 0, but GFF counts from 1
    foreach my $c (@cds) {
        ( $c->{from}, $c->{to} ) = map  { $_ + 1 }    ( $c->{from}, $c->{to} );
    }
    @cds = $self->sort_tags(\@cds, 'from', 'to');
}

#TODO: This was essentially copied from /lims/lib/GSC/ImportExport.pm, and badly needs refactoring
sub retrieve_UTR{
    my ($self, $transcript) = @_;
    unless ($transcript){
        $self->error_message("No transcript specified, exiting");
        return;
    }

    my $acc = $transcript->{accession};

    my @exons = $self->retrieve_exons($transcript);
    return unless @exons;

    my @utr = ();

    my %common_params = (
        ref_class_name => "Bio::DNA::UTR",
        text           => "mRNA $acc",
    );

    my $count = 1;
    if (!exists($transcript->{'products'}) || @{ $transcript->{'products'}} == 0) {
        ## Thar be no protein!  Okay, boys and girls, we're going to make some stuff up...
        foreach my $exon (@exons) {
            push @utr,
                {
                begin_position => $exon->{from},
                end_position   => $exon->{to},
                ref_id         => "$acc.cdsutr.$count",
                strand         => $exon->{strand} eq 'plus' ? '+1' : '-1',
                %common_params
                };
            $count++;
        }
    }
    else {
        my $protein = @{ $transcript->{'products'} }[0];

        my @cds = $self->retrieve_CDS($transcript);
        return unless @cds;
        my $cds_start = $cds[0]->{from};
        my $cds_stop  = $cds[-1]->{to};

        foreach my $exon (@exons) {
            last if ( $exon->{from} == $cds_start );
            
            if ( $exon->{to} < $cds_start ) {
                push @utr,
                    {
                     begin_position => $exon->{from},
                     end_position   => $exon->{to},
                     ref_id         => "$acc.cdsutr.$count",
                     strand         => $exon->{strand} eq 'plus' ? '+1' : '-1',
                     %common_params
                    };
                $count++;
                next;
            }
            else {
                push @utr,
                    {
                     begin_position => $exon->{from},
                     end_position   => $cds_start - 1,
                     ref_id         => "$acc.cdsutr.$count",
                     strand         => $exon->{strand} eq 'plus' ? '+1' : '-1',
                     %common_params
                    };
               $count++;
               last;
           }
       }

       foreach my $exon ( reverse @exons ) {
           last if ( $exon->{to} == $cds_stop );
            
           if ( $exon->{from} > $cds_stop ) {
               push @utr,
                   {
                    begin_position => $exon->{from},
                    end_position   => $exon->{to},
                    ref_id         => "$acc.cdsutr.$count",
                    strand         => $exon->{strand} eq 'plus' ? '+1' : '-1',
                    %common_params
                   };
               $count++;
               next;
           }
           else {
               push @utr,
                   {
                    begin_position => $cds_stop + 1,
                    end_position   => $exon->{to},
                    ref_id         => "$acc.cdsutr.$count",
                    strand         => $exon->{strand} eq 'plus' ? '+1' : '-1',
                    %common_params
                   };
               $count++;
               last;
           }
       }
   }
   return @utr;
}

sub retrieve_transcripts {
    my ($self, $gene_hash) = @_;
    my ($locus) = @{$gene_hash->[0]->{'locus'}};
    unless (defined $locus) {
        $locus = @{$gene_hash->[0]->{'locus'}}[0];
    }

    my @products;
    if (exists $locus->{'products'}) {
        push @products, @{$locus->{'products'}};
    }
    
    unless (@products){
        # TODO Make this more descriptive
        $self->warning_message("No transcripts found for gene!");
    }

    my @transcripts = grep {$_->{'type'} = 'mRNA'} @products;
    return @transcripts;
}

sub cache_transcript_status
{
    my $self = shift;

    my $seqio = new Bio::SeqIO(
        -file   => $self->genbank_file,
        -format => 'genbank'
    );

    my %ts_status_hash;
    #Check storable status so we don't have to regenerate this file
    my $storable_file = "/gscmnt/sata835/info/medseq/annotation_data/genbank_transcript_status_cache/".$self->species.".".$self->version;

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
                #This is a hack.  We need the version number so that we can append it in the format join(".", $transcript_name, $version_number);
                #We do this because Genbank does not do organized releases.  The version transcripts using a scheme similar to this, which leads to confusion.  
                #We do this here because this is the only place that we parse this file.  It is crappy and hacky, but so it this entire process.
                my ($transcript_version) = $feature->{_gsf_seq}->{_version}; 
                foreach my $val (@values)
                {
                    if ( $val =~ /GeneID/x )
                    {

                        #TODO if this is always expected to exist, we should handle it
                        # will look like GeneID:144448 or GeneID:(\d+)
                        $val =~ s/GeneID:(\d+)/$1/x;
                        $ts_status_hash{ $seq->display_id }->{entrezid} = $val;
                        $ts_status_hash{ $seq->display_id }->{hugo_gene_name} = $hugo;
                        $ts_status_hash{ $seq->display_id }->{transcript_version} = $transcript_version;
                    }
                }

            }

        }
        #return \%ts_status_hash;
    }

    #store this file so we don't have to do it every time
    nstore \%ts_status_hash, $storable_file;

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
    my @exons = $self->retrieve_exons($transcript );
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
    unless ($seq) {
        $self->warning_message("Cannot reverse complement an empty sequence string, returning undef");
        return;
    }
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
    $slice = $reference_build->sequence($chrom, $start, $stop);
    return $slice;
}

# TODO This needs to be cleaned up... badly
sub set_reference_build
{
    my $self = shift;
    unless ($self->reference_build){
        my $species = $self->species;
        # Currently only supports versions in familiar formats(54_36p, 54_37g) 
        # Possible these will get more complicated later
        #TODO: This needs some sort of fix to use the correct version or the ref (or more likely ask what the correct ref seq is)
        my ($reference_build_version) = $self->version =~ /^\d+_(\d+)[a-z]$/; 
        my $model = Genome::Model::ImportedReferenceSequence->get(name => "NCBI-$species");
        confess "Couldn't get imported reference sequence for $species!" unless $model;

        my $build = $model->build_by_version($reference_build_version);
        confess "Couldn't get build version $reference_build_version for $species!" unless $build;
        $self->reference_build($build);
    }
    return $self->reference_build;
}

1;

# $Id$
