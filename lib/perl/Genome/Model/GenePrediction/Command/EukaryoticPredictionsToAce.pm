package Genome::Model::GenePrediction::Command::EukaryoticPredictionsToAce;

use strict;
use warnings;
use Genome;
use Carp 'confess';
use Sort::Naturally qw/ ncmp nsort /;

class Genome::Model::GenePrediction::Command::EukaryoticPredictionsToAce {
    is => 'Genome::Command::Base',
    has => [
        model => { 
            is => 'Genome::Model', 
            id_by => 'model_id' 
        },
        ace_file => {
            is => 'Path',
            doc => 'Path for output ace file',
        },
    ],
    has_optional => [
        protein_coding_only => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, only genes that produce proteins are placed in ace file',
        },
    ],
};

sub help_brief {
    return "Generates an ace file from predictions creates by a eukaryotic gene prediction build";
}

sub help_synopsis {
    return "Generates an ace file from predictions creates by a eukaryotic gene prediction build";
}

sub help_detail {
    return "Generates an ace file from predictions creates by a eukaryotic gene prediction build";
}
    
sub execute {
    $DB::single = 1;
    my $self = shift;
    my $model = $self->model;
    confess "Could not get model " . $self->model_id unless $model;

    my $class = $self->model->class;
    unless ($class =~ /GenePrediction::Eukaryotic/i) {
        confess "Model is not eukaryotic gene prediction, type is $class";
    }

    my $build = $self->model->last_succeeded_build;
    confess "Could not get successful build for model " . $self->model_id unless $build;
    
    $self->status_message("Using predictions from build " . $build->build_id);

    # Pre-fetching all genes now so only one file read is necessary
    my @coding_genes = Genome::Prediction::CodingGene->get(
        directory => $build->prediction_directory,
    );
    my @rna_genes = Genome::Prediction::RNAGene->get(
        directory => $build->prediction_directory,
    );

    my $ace_fh = IO::File->new(">" . $self->ace_file);
    confess "Could not get handle for " . $self->ace_file unless $ace_fh;
        
    # Get list of sequences
    my $sequences = $build->sequences;
    for my $sequence (nsort @$sequences) { 
        my @seq_coding_genes = Genome::Prediction::CodingGene->get(
            directory => $build->prediction_directory,
            sequence_name => $sequence,
        );
        my @seq_rna_genes;
        @seq_rna_genes = Genome::Prediction::RNAGene->get(
            directory => $build->prediction_directory,
            sequence_name => $sequence,
        ) unless $self->protein_coding_only;

        for my $gene (sort { ncmp($a->gene_name, $b->gene_name) } @seq_coding_genes) {
            my $gene_name = $gene->gene_name;
            my $start = $gene->start;
            my $end = $gene->end;
            ($start, $end) = ($end, $start) if $gene->strand eq '-1';
            my $source = $gene->source;
            my $strand = $gene->strand;

            $ace_fh->print("Sequence $sequence\n");
            $ace_fh->print("Subsequence $gene_name $start $end\n\n");

            my ($transcript) = $gene->transcript;
            my @exons = $transcript->exons;
            @exons = sort { $a->start <=> $b->start } @exons;
            @exons = reverse @exons if $transcript->strand eq '-1';

            my $spliced_length = 0;
            for my $exon (@exons) {
                $spliced_length += abs($exon->end - $exon->start) + 1;
            }

            $ace_fh->print("Sequence : $gene_name\n");
            $ace_fh->print("Source $sequence\n");

            # FIXME Dirty dirty snap hack
            my $method = $source;
            if ($method =~ /snap/i) {
                my @fields = split(/\./, $gene_name);
                # For snap, the gene name template is contig_name.predictor.model_file_abbrev.gene_number
                # We are interested in the predictor name (snap, in this case) and the model file
                $method = join('.', $fields[1], $fields[2]);
            }
            $ace_fh->print("Method $method\n");
            $ace_fh->print("CDS\t1 $spliced_length\n");
            $ace_fh->print("CDS_predicted_by $source\n");

            if ($gene->missing_start) {
                my $frame = $exons[0]->five_prime_overhang;
                $frame++;  # Predictors use frame 0 - 2, ace requires frame 1 - 3
                $ace_fh->print("Start_not_found $frame\n");
            }
            if ($gene->missing_stop) {
                $ace_fh->print("End_not_found\n");
            }

            my $transcript_start = $transcript->start;
            my $transcript_end = $transcript->end;

            for my $exon (@exons) {
                my $exon_start = $exon->start;
                my $exon_end = $exon->end;

                if ($exon_start > $exon_end) {
                    ($exon_start, $exon_end) = ($exon_end, $exon_start);
                }

                my ($exon_ace_start, $exon_ace_end);
            
                if ($gene->strand eq '+1') {    
                    $exon_ace_start = $exon_start - $transcript_start + 1;
                    $exon_ace_end = $exon_end - $transcript_start + 1;
                }
                elsif ($gene->strand eq '-1') {            
                    $exon_ace_start = $transcript_end - $exon_end + 1;
                    $exon_ace_end = $transcript_end - $exon_start + 1;
                }
                else {
                    die "Bad strand for coding gene " . $gene->gene_name . ": " . $gene->strand;
                }

                $ace_fh->print("Source_Exons $exon_ace_start $exon_ace_end\n");
            }
            $ace_fh->print("\n");
        }

        for my $gene (sort { ncmp($a->gene_name, $b->gene_name) } @seq_rna_genes) {
            my $gene_name = $gene->gene_name;
            my $accession = $gene->accession;
            my $codon = $gene->codon;
            my $amino_acid = $gene->amino_acid;
            my $amino_acid_code = substr($amino_acid, 0, 1);
            my $gene_score = $gene->score;
            my $source = $gene->source;

            my $start = $gene->start;
            my $end = $gene->end;
            ($start, $end) = ($end, $start) if $start > $end;
            
            $ace_fh->print("Sequence $sequence\n");
            $ace_fh->print("Subsequence $gene_name $start $end\n\n");
            $ace_fh->print("Sequence : $gene_name\n");
            $ace_fh->print("Source $sequence\n");

            my ($method, $remark, $transcript, $locus);
            if ($source =~ /trnascan/i) {
                $method = 'tRNAscan';
                $remark = "\"tRNA-$amino_acid Sc=$gene_score\"";
                $transcript = "tRNA $codon $amino_acid $amino_acid_code";
            }
            elsif ($source =~ /rfam/i) {
                $method = 'Rfam';
                $remark = "\"Predicted by Rfam ($accession), score $gene_score\"";
                $locus = $gene->description;
            }
            elsif ($source =~ /rnammer/i) {
                $method = 'RNAmmer';
                $remark = "\"Predicted by RNAmmer, score $gene_score\"";
                $locus = $gene->description;
            }
            else {
                $method = $source;
                $remark = "\"Predicted by $method, score $gene_score\$";
                $locus = $gene->description;
            }

            $ace_fh->print("Method $method\n") if defined $method;
            $ace_fh->print("Remark $remark\n") if defined $remark;
            $ace_fh->print("Locus $locus\n") if defined $locus;
            $ace_fh->print("Transcript $transcript\n") if defined $transcript;
            $ace_fh->print("\n");
        }
    }

    $ace_fh->close;
    return 1;
}


1;

