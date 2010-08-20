package EGAP::Command::UploadResult;

use strict;
use warnings;

use EGAP;

use Bio::SeqIO;
use Bio::SeqFeature::Generic;
use Bio::Tools::Prediction::Gene;
use Bio::Tools::Prediction::Exon;

use Data::Dumper;
use Carp;

class EGAP::Command::UploadResult {
    is  => 'EGAP::Command',
    has => [
        seq_set_id => {
            is  => 'Number',
            is_input => 1,
            doc => 'Identifies an assembly in the EGAP database',
        },
        bio_seq_features => {
            is  => 'ARRAY',
            is_input => 1,
            doc => 'array of Bio::Seq::Feature'
        },
    ],
};

sub help_brief {
    return "Uploads predictions from EGAP to the database";
}

sub help_synopsis {
    return <<EOS
Takes a list of features (predictions made by EGAP), converts them to EGAP
objects, and commits those objects to the EGAP database.
EOS
}

sub help_detail {
    return <<EOS
Takes a list of features (predictions made by EGAP), converts them to EGAP
objects, and commits those objects to the EGAP database.
EOS
}

sub execute {
    my $self = shift;

    my $sequence_set_id = $self->seq_set_id();
    my $sequence_set    = EGAP::SequenceSet->get($sequence_set_id);
    my @sequences = $sequence_set->sequences();

    # All previous predictions are wiped out
    $self->warning_message("Removing all prior predictions in the database for sequence set id $sequence_set_id!");
    for my $sequence (@sequences) {
        $self->_delete_predictions_for_sequence($sequence);
    }
    $self->status_message("All previous predictions successfully removed!");

    $self->{_gene_count} = {};
    my %features;

    # Group features by sequence id
    for my $ref (@{$self->bio_seq_features()}) {
        my @fixup;
        if (ref($ref) eq 'ARRAY') {
            @fixup = @{$ref};
        }
        else {
            push @fixup, $ref;
        }
        
        for my $feature (@fixup) {
            if (defined($feature)) {
                push @{$features{$feature->seq_id()}}, $feature;
            }
        }
    }

    # Iterate through seq ids, create transcript/gene/exon/protein objects
    for my $seq_id ( keys %features ) {
        $self->{_gene_count}{$seq_id}{fgenesh}  = 0;
        $self->{_gene_count}{$seq_id}{snap}     = 0;
        $self->{_gene_count}{$seq_id}{trnascan} = 0;
        $self->{_gene_count}{$seq_id}{rnammer}  = 0;
        $self->{_gene_count}{$seq_id}{rfam}     = 0;

        my $sequence = EGAP::Sequence->get(
            sequence_set_id => $sequence_set_id,
            sequence_name   => $seq_id,
        );

        my $sequence_id = $sequence->sequence_id();

        my $seq_obj = Bio::Seq->new(
            -seq => $sequence->sequence_string(),
            -id  => $sequence->sequence_name(),
        );

        my @features = @{ $features{$seq_id} };

        for my $feature (@features) {
            my $source = $feature->source_tag();

            if ( $source eq 'Fgenesh' ) {
                $self->{_gene_count}{$seq_id}{fgenesh}++;
                $self->_store_coding_gene( $sequence_id, $feature, $seq_obj );
            }
            elsif ( $source eq 'SNAP' ) {
                $self->{_gene_count}{$seq_id}{snap}++;
                $self->_store_coding_gene( $sequence_id, $feature, $seq_obj );
            }
            elsif ( $source eq 'tRNAscan-SE' ) {
                $self->{_gene_count}{$seq_id}{trnascan}++;
                $self->_store_trnascan( $sequence_id, $feature );
            }
            elsif ( $source =~ /^RNAmmer/ ) {
                $self->{_gene_count}{$seq_id}{rnammer}++;
                $self->_store_rnammer( $sequence_id, $feature );
            }
            elsif ( $source eq 'Infernal' ) {
                $self->{_gene_count}{$seq_id}{rfam}++;
                $self->_store_rfamscan( $sequence_id, $feature );
            }
        }
    }

    UR::Context->commit();
    return 1;
}

sub _delete_predictions_for_sequence {
    my ($self, $sequence) = @_;

    my @coding_genes = $sequence->coding_genes();
    my @trna_genes = $sequence->trna_genes();
    my @rna_genes = $sequence->rna_genes();

    for my $gene (@coding_genes) {
        my @transcripts = $gene->transcripts;

        for my $transcript (@transcripts) {
            my @proteins = EGAP::Protein->get(transcript => $transcript);
            my @exons = $transcript->exons;

            for my $protein (@proteins) {
                my $protein_id = $protein->id;
                my $rv = $protein->delete();
                confess "Could not remove protein $protein_id!" unless $rv;
            }
            for my $exon (@exons) {
                my $exon_id = $exon->id;
                my $rv = $exon->delete();
                confess "Could not remove exon $exon_id!" unless $rv;
            }

            my $transcript_id = $transcript->id;
            my $rv = $transcript->delete();
            confess "Could not remove transcript $transcript_id!" unless $rv;
        }
    }

    for my $gene (@trna_genes, @rna_genes ) {
        $gene->delete();
    }

    return 1;
}

sub _store_coding_gene {
    my ($self, $sequence_id, $feature, $seq_obj) = @_;

    my $source = lc($feature->source_tag());
    
    my $gene_name = join '.', $feature->seq_id(), $source,
        $self->{_gene_count}{ $feature->seq_id() }{$source};

    my $start = $feature->start();
    my $end   = $feature->end();
    my $strand = $feature->strand();
    
    # Exons are ordered by position, not necessarily by transcription order
    # This is important for negative stranded transcripts below
    my @exons = $feature->exons_ordered();

    my $cds_start = $exons[0]->start();
    my $cds_end   = $exons[0]->end();

    my $missing_start = 0;
    my $missing_stop = 0;
    my $fragment = 0;

    if ($feature->has_tag('start_not_found')) {
        $missing_start = 1;
    }

    if ($feature->has_tag('end_not_found')) {
        $missing_stop = 1;
    }

    if ($feature->has_tag('fragment')) {
        $fragment = 1;
    }
    
    my $gene = EGAP::CodingGene->create(
        gene_name       => $gene_name,
        sequence_id     => $sequence_id,
        start           => $start,
        end             => $end,
        strand          => $strand,
        source          => $source,
        missing_start   => $missing_start,
        missing_stop    => $missing_stop,
        fragment        => $fragment,
        sequence_string => $seq_obj->subseq($start, $end),
    );
    unless ($gene) {
        confess "Could not create gene object with name $gene_name!";
    }   

    my $transcript = EGAP::Transcript->create(
        transcript_name => "$gene_name.1",
        gene_id         => $gene->gene_id(),
        start           => $cds_start,
        end             => $cds_end,
        coding_start    => 1, 
        coding_end      => ($cds_end - $cds_start) + 1, 
        sequence_string => $seq_obj->subseq($cds_start, $cds_end),
    );
    unless ($transcript) {
        confess "Could not create transcript object for gene $gene_name!";
    }

    my $exon_seq_string;
    for my $exon (@exons) {
        my $exon_start = $exon->start();
        my $exon_end   = $exon->end();
        my $five_prime_overhang = $exon->get_tag_values('five_prime_overhang');
        my $three_prime_overhang = $exon->get_tag_values('three_prime_overhang');

        my $exon_seq = $seq_obj->subseq($exon_start, $exon_end);
        $exon_seq_string .= $exon_seq;
        
        my $exon = EGAP::Exon->create(
            transcript_id        => $transcript->transcript_id(),
            start                => $exon_start,
            end                  => $exon_end,
            sequence_string      => $exon_seq,
            five_prime_overhang  => $five_prime_overhang,
            three_prime_overhang => $three_prime_overhang,
        );
        unless ($exon) {
            confess "Could not create exon object for transcript " . $transcript->transcript_id() . "!";
        }
    }

    my $transcript_seq = Bio::Seq->new(
        -id  => $transcript->transcript_name(),
        -seq => $exon_seq_string,
    );
    if ($strand eq '-1') {
        $transcript_seq = $transcript_seq->revcom();
    }

    # If this is a fragment, need to figure out how many bases to cut off the front before translating
    if ($fragment) {
        my $first_exon_overhang = $exons[0]->get_tag_values('five_prime_overhang');
        $first_exon_overhang = $exons[-1]->get_tag_values('five_prime_overhang') if $strand eq '-1';
        $transcript_seq = $transcript_seq->trunc($first_exon_overhang, $transcript_seq->length());
    }
        
    my $protein_seq = $transcript_seq->translate();
    
    # Check if the translated sequence contains an internal stop codon
    my $internal_stops = 0;
    my $stop = index($protein_seq, '*');
    unless ($stop == -1 or $stop == (length($protein_seq) - 1)) {
        $internal_stops = 1;
    }
    
    my $protein = EGAP::Protein->create(
        protein_name    => $transcript->transcript_name(),
        transcript_id   => $transcript->transcript_id(),
        internal_stops  => $internal_stops,
        sequence_string => $protein_seq->seq(),
    );
    unless ($protein) {
        confess "Could not create protein object for transcript " . $transcript->transcript_name() . "!";
    }
    
    $gene->internal_stops($internal_stops);
    return 1;

}

sub _store_trnascan {
    my ($self, $sequence_id, $feature, $seq_obj) = @_;

    my $gene_name = join('.',
        $feature->seq_id(),
        (join( '',
            't', $self->{_gene_count}{ $feature->seq_id() }{'trnascan'} )
        )
    );
    
    my ($codon) = $feature->each_tag_value('Codon');
    my ($aa)    = $feature->each_tag_value('AminoAcid');

    my $trna_gene = EGAP::tRNAGene->create(
        gene_name   => $gene_name,
        sequence_id => $sequence_id,
        start       => $feature->start(),
        end         => $feature->end(),
        strand      => $feature->strand(),
        source      => 'trnascan',
        score       => $feature->score(),
        codon       => $codon,
        aa          => $aa,
    );
    unless ($trna_gene) {
        confess "Could not create tRNAGene object for gene $gene_name!";
    }

    return 1;
}

sub _store_rnammer {
    my ($self, $sequence_id, $feature) = @_;

    my $gene_name = join '.',
        $feature->seq_id(),
        'rnammer',
        $self->{_gene_count}{ $feature->seq_id() }{'rnammer'};

    my $score         = $feature->score();
    my ($description) = $feature->each_tag_value('group');

    my $rna_gene = EGAP::RNAGene->create(
        gene_name   => $gene_name,
        sequence_id => $sequence_id,
        start       => $feature->start(),
        end         => $feature->end(),
        acc         => 'RNAmmer',
        description => $description,
        strand      => $feature->strand(),
        source      => 'rnammer',
        score       => $score,
    );
    unless ($rna_gene) {
        confess "Could not create RNAGene object for gene $gene_name!";
    }

    return 1;
}

sub _store_rfamscan {
    my ( $self, $sequence_id, $feature ) = @_;

    my $gene_name = join '.', 
        $feature->seq_id(), 
        'rfam',
        $self->{_gene_count}{$feature->seq_id()}{'rfam'};

    my $score              = $feature->score();
    my ($rfam_accession)   = $feature->each_tag_value('acc');
    my ($rfam_description) = $feature->each_tag_value('id');

    unless (($score <= 50) or ($rfam_description =~ /tRNA/i)) {
        my $rna_gene = EGAP::RNAGene->create(
            gene_name   => $gene_name,
            sequence_id => $sequence_id,
            start       => $feature->start(),
            end         => $feature->end(),
            acc         => $rfam_accession,
            description => $rfam_description,
            strand      => $feature->strand(),
            source      => 'rfam',
            score       => $score,
        );
        unless ($rna_gene) {
            confess "Could not create RNAGene for gene $gene_name!";
        }
    }

    return 1;
}

1;
