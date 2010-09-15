package EGAP::Command::GenePredictor::Fgenesh;

use strict;
use warnings;

use EGAP;

use Bio::SeqIO;
use Bio::Tools::Run::Fgenesh;

use Carp 'confess';
use File::Path 'make_path';

class EGAP::Command::GenePredictor::Fgenesh {
    is => 'EGAP::Command::GenePredictor',
    has => [
        model_file => { 
            is => 'Path', 
            is_input => 1,
            doc => 'Path to the model file for this fasta' 
        },
    ],
};

sub help_brief {
    return "Runs the fgenesh gene prediction tool";
}

sub help_synopsis {
    return <<EOS
Runs the fgenesh gene prediction tool on the sequence in the provided fasta file.
EOS
}

sub help_detail {
    return <<EOS
Runs the fgenesh gene prediction tool on the sequence in the provided fasta file.
An HMM file is also necessary to train the predictor. Predictions are held in the
command object's bio_seq_feature parameter.
EOS
}

sub execute {
    my $self = shift;
    my @features;
    my $output_directory = $self->output_directory;

    unless (-d $output_directory) {
        my $mkdir_rv = make_path($output_directory);
        confess "Could not make directory $output_directory" unless $mkdir_rv;
    }

    my $seqio = Bio::SeqIO->new(
        -format => 'Fasta', 
        -file => $self->fasta_file
    );

    while (my $seq = $seqio->next_seq()) {
        # TODO Need to get raw output capture to work correctly...
        my $factory = Bio::Tools::Run::Fgenesh->new(
            -program => 'fgenesh',
            -param   =>  $self->model_file,
        );
        my $parser = $factory->run($seq);

        # Parse and process each prediction...
        while (my $gene = $parser->next_prediction()) {
            my @exons = $gene->exons();

            # We always want start < stop, regardless of strand
            foreach my $exon (@exons) {
                my $start = $exon->start();
                my $end   = $exon->end();

                if ($start > $end) {
                    ($start, $end) = ($end, $start);
                    $exon->start($start);
                    $exon->end($end);
                }
            }

            # Exons are originally sorted in the order they would be transcibed (strand)
            # We always want to start < stop, regardless of strand
            @exons = sort { $a->start() <=> $b->start() } @exons;

            my $new_gene = Bio::Tools::Prediction::Gene->new(
                -seq_id     => $gene->seq_id(),
                -start      => $exons[0]->start(),
                -end        => $exons[$#exons]->end(),
                -strand     => $exons[0]->strand(),
                -source_tag => $exons[0]->source_tag(),
            );

            # Set errors on gene if its missing expected exons
            if (@exons > 1) {
                unless ($exons[0]->primary_tag() eq 'InitialExon' or 
                    $exons[$#exons]->primary_tag() eq 'InitialExon') {
                    $new_gene->add_tag_value('start_not_found' => 1);
                    $new_gene->add_tag_value('fragment' => 1);
                }
                unless ($exons[0]->primary_tag() eq 'TerminalExon' or 
                    $exons[$#exons]->primary_tag() eq 'TerminalExon') {
                    $new_gene->add_tag_value('end_not_found' => 1);
                    $new_gene->add_tag_value('fragment' => 1);
                }
            }
            elsif (@exons == 1) {
                unless ($exons[0]->primary_tag() eq 'SingletonExon') {
                    $new_gene->add_tag_value('fragment' => 1);

                    unless ($exons[0]->primary_tag() eq 'TerminalExon') {
                        $new_gene->add_tag_value('end_not_found' => 1);
                    }
                    unless ($exons[0]->primary_tag() eq 'InitialExon') {
                        $new_gene->add_tag_value('start_not_found' => 1);
                    }
                }
            }

            # Calculate five prime and three prime overhang using frame value
            foreach my $exon (@exons) {
                my $frame = $exon->frame();
                my $length = $exon->length();

                my $five_prime_overhang = $frame;
                my $three_prime_overhang = ($length - $five_prime_overhang) % 3;

                $exon->add_tag_value('five_prime_overhang' => $five_prime_overhang);
                $exon->add_tag_value('three_prime_overhang' => $three_prime_overhang);
                $new_gene->add_exon($exon);
            }

            push @features, $new_gene;
        }
    }

    $self->bio_seq_feature(\@features);
    return 1;
}

1;
