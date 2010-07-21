package EGAP::Command::UploadResult;

use strict;
use warnings;

use Workflow;

use Bio::SeqIO;
use Bio::SeqFeature::Generic;
use Bio::Tools::Prediction::Gene;
use Bio::Tools::Prediction::Exon;

use Data::Dumper;

class EGAP::Command::UploadResult {
    is  => ['MGAP::Command'],
    has => [
        seq_set_id => {
            is  => 'SCALAR',
            doc => 'identifies a whole assembly'
        },
        bio_seq_features => {
            is  => 'ARRAY',
            doc => 'array of Bio::Seq::Feature'
        },
    ],
};

operation_io EGAP::Command::UploadResult {
    input  => [ 'bio_seq_features', 'seq_set_id' ],
    output => [],
};

sub sub_command_sort_position {10}

sub help_brief {
    "Store input gene predictions in the EGAP schema";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {

    my $self = shift;

    my $sequence_set_id = $self->seq_set_id();
    my $sequence_set    = EGAP::SequenceSet->get($sequence_set_id);

    my @sequences = $sequence_set->sequences();

    foreach my $sequence (@sequences) {

        my @coding_genes = $sequence->coding_genes();
        my @trna_genes   = $sequence->trna_genes();
        my @rna_genes    = $sequence->rna_genes();

        foreach my $gene ( @coding_genes, @trna_genes, @rna_genes ) {
            $gene->delete();
        }

    }

    $self->{_gene_count} = {};

    my %features = ();

    foreach my $ref ( @{ $self->bio_seq_features() } ) {

        my @fixup = ( );

        if (ref($ref) eq 'ARRAY') {
            @fixup = @{$ref};
        }
        else {
            push @fixup, $ref;
            
        }
        
        foreach my $feature ( @fixup ) {
            if (defined($feature)) {
                push @{ $features{ $feature->seq_id() } }, $feature;
            }
        }
        
    }

    foreach my $seq_id ( keys %features ) {

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

        foreach my $feature (@features) {

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

sub _store_coding_gene {

    my ( $self, $sequence_id, $feature, $seq_obj ) = @_;

    my $source = lc($feature->source_tag());
    
    my $gene_name = join '.', $feature->seq_id(), $source,
        $self->{_gene_count}{ $feature->seq_id() }{$source};

    my $start = $feature->start();
    my $end   = $feature->end();
    
    my @exons = $feature->exons_ordered();

    my $exon_start = $exons[0]->start();
    my $exon_end   = $exons[0]->end();

    my $missing_start = 0;
    my $missing_stop  = 0;

    if ($feature->has_tag('start_not_found')) {
        $missing_start = 1;
    }

    if ($feature->has_tag('end_not_found')) {
        $missing_stop = 1;
    }
    
    my $gene = EGAP::CodingGene->create(
        gene_name       => $gene_name,
        sequence_id     => $sequence_id,
        start           => $feature->start(),
        end             => $feature->end(),
        strand          => $feature->strand(),
        source          => $source,
        internal_stops  => 0,
        missing_start   => $missing_start,
        missing_stop    => $missing_stop,
        fragment        => 0,
        wraparound      => 0,
        blastp_evidence => 0,
        pfam_evidence   => 0,
        sequence_string => $seq_obj->subseq($start, $end),
    );

    my $transcript = EGAP::Transcript->create(
        transcript_name => "$gene_name.1",
        gene_id         => $gene->gene_id(),
        start           => $exon_start,
        end             => $exon_end,
        coding_start    => 1,
        coding_end      => ($exon_end - $exon_start) + 1,
        sequence_string => $seq_obj->subseq($exon_start, $exon_end),
    );

    my $exon_seq_string;
    
    foreach my $exon (@exons) {

        my $start = $exon->start();
        my $end   = $exon->end();

        my $substring = $seq_obj->subseq($start, $end);

        $exon_seq_string .= $substring;
        
        EGAP::Exon->create(
            transcript_id   => $transcript->transcript_id(),
            start           => $exon->start(),
            end             => $exon->end(),
            sequence_string => $substring,
        );

    }

    my $transcript_seq = Bio::Seq->new(
        -id  => $transcript->transcript_name(),
        -seq => $exon_seq_string,
    );

    my $protein_seq = $transcript_seq->translate();
    
    EGAP::Protein->create(
        protein_name    => $transcript->transcript_name(),
        transcript_id   => $transcript->transcript_id(),
        internal_stops  => 0,
        sequence_string => $protein_seq->seq(),
    );
    
    return 1;

}

sub _store_trnascan {

    my ( $self, $sequence_id, $feature, $seq_obj ) = @_;

    my $gene_name = join(
        '.',
        $feature->seq_id(),
        (   join( '',
                't', $self->{_gene_count}{ $feature->seq_id() }{'trnascan'} )
        )
    );
    
    my ($codon) = $feature->each_tag_value('Codon');
    my ($aa)    = $feature->each_tag_value('AminoAcid');

    EGAP::tRNAGene->create(
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

}

sub _store_rnammer {

    my ( $self, $sequence_id, $feature ) = @_;

    my $gene_name = join '.',
        $feature->seq_id(),
        'rnammer',
        $self->{_gene_count}{ $feature->seq_id() }{'rnammer'};

    my $score         = $feature->score();
    my ($description) = $feature->each_tag_value('group');

    EGAP::RNAGene->create(
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

}

sub _store_rfamscan {

    my ( $self, $sequence_id, $feature ) = @_;

    my $gene_name = join '.', $feature->seq_id(), 'rfam',
        $self->{_gene_count}{ $feature->seq_id() }{'rfam'};

    my $score              = $feature->score();
    my ($rfam_accession)   = $feature->each_tag_value('acc');
    my ($rfam_description) = $feature->each_tag_value('id');

    unless ( ( $score <= 50 ) || ( $rfam_description =~ /tRNA/i ) ) {

        EGAP::RNAGene->create(
            {   gene_name   => $gene_name,
                sequence_id => $sequence_id,
                start       => $feature->start(),
                end         => $feature->end(),
                acc         => $rfam_accession,
                description => $rfam_description,
                strand      => $feature->strand(),
                source      => 'rfam',
                score       => $score,
            }
        );

    }

}

1;
