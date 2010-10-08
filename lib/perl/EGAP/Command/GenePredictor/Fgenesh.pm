package EGAP::Command::GenePredictor::Fgenesh;

# TODO I think a lot of code is duplicated between this module
# and SNAP. Look into fixing this...

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
        coding_gene_prediction_file => {
            is => 'Path',
            is_input => 1,
            is_output => 1,
            doc => 'File containing coding gene predictions',
        },
        transcript_prediction_file => {
            is => 'Path',
            is_input => 1,
            is_output => 1,
            doc => 'File containing transcript predictions',
        },
        exon_prediction_file => {
            is => 'Path',
            is_input => 1,
            is_output => 1,
            doc => 'File containing exon predictions',
        },
        protein_prediction_file => {
            is => 'Path',
            is_input => 1,
            is_output => 1,
            doc => 'File containing protein predictions',
        },
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
    my $output_directory = $self->raw_output_directory;

    unless (-d $output_directory) {
        my $mkdir_rv = make_path($output_directory);
        confess "Could not make directory $output_directory" unless $mkdir_rv;
    }

    my $seqio = Bio::SeqIO->new(
        -format => 'Fasta', 
        -file => $self->fasta_file
    );

    my $gene_count = 0;
    while (my $seq = $seqio->next_seq()) {
        $self->status_message("Now parsing predictions from sequence " . $seq->id());

        # TODO Need to get raw output capture to work correctly...
        my $factory = Bio::Tools::Run::Fgenesh->new(
            -program => 'fgenesh',
            -param   =>  $self->model_file,
        );
        my $parser = $factory->run($seq);
        my $current_seq_name = $seq->id();

        # Parse and process each prediction...
        while (my $gene = $parser->next_prediction()) {
            my $strand = $gene->strand();
            my $source = $gene->source_tag();
            my $gene_name = join('.', $current_seq_name, $source, $gene_count);
            my $transcript_name = $gene_name . '.1';
            $gene_count++;

            my @predicted_exons = $gene->exons();

            # We always want start < stop, regardless of strand
            foreach my $exon (@predicted_exons) {
                my $exon_start = $exon->start();
                my $exon_end   = $exon->end();

                if ($exon_start > $exon_end) {
                    ($exon_start, $exon_end) = ($exon_end, $exon_start);
                    $exon->start($exon_start);
                    $exon->end($exon_end);
                }
            }

            my $start = $predicted_exons[0]->start();
            my $end = $predicted_exons[-1]->end();

            # Exons are originally sorted in the order they would be transcibed (strand)
            # We always want to start < stop, regardless of strand
            @predicted_exons = sort { $a->start() <=> $b->start() } @predicted_exons;

            # If a gene has multiple exons, it's expected that the first exon have tag InitialExon and the last exon have
            # tag TerminalExon. If a gene has only one exon, it should have tag SingletonExon. If this expected behavior
            # isn't found, then certain flags are set and stored on the gene
            my ($missing_start, $missing_stop, $fragment, $internal_stops) = (0,0,0,0);
            if (@predicted_exons > 1) {
                unless ($predicted_exons[0]->primary_tag() eq 'InitialExon' or $predicted_exons[-1]->primary_tag() eq 'InitialExon') {
                    $missing_start = 1;
                    $fragment = 1;
                }
                unless ($predicted_exons[0]->primary_tag() eq 'TerminalExon' or $predicted_exons[-1]->primary_tag() eq 'TerminalExon') {
                    $missing_stop = 1;
                    $fragment = 1;
                }
            }
            elsif (@predicted_exons == 1) {
                unless ($predicted_exons[0]->primary_tag() eq 'SingletonExon') {
                    $fragment = 1;
                    unless ($predicted_exons[0]->primary_tag() eq 'TerminalExon') {
                        $missing_stop = 1;
                    }
                    unless ($predicted_exons[0]->primary_tag() eq 'InitialExon') {
                        $missing_start = 1;
                    }
                }
            }

            # Now construct exon sequence, determine overhang, and create EGAP::Exon objects
            my @exons;
            my $exon_sequence_string;
            my $exon_count = 0;
            for my $predicted_exon (@predicted_exons) {
                my $frame = $predicted_exon->frame();
                my $length = $predicted_exon->length();
                my $five_prime_overhang = $frame;
                my $three_prime_overhang = ($length - $five_prime_overhang) % 3;

                my $exon_name = $transcript_name . ".exon.$exon_count";
                $exon_count++;

                my $exon_seq = $seq->subseq($predicted_exon->start(), $predicted_exon->end());
                $exon_sequence_string .= $exon_seq;

                my $exon = EGAP::Exon->create(
                    file_path => $self->exon_prediction_file,
                    exon_name => $exon_name,
                    start => $predicted_exon->start(),
                    end => $predicted_exon->end(),
                    strand => $predicted_exon->strand(),
                    score => $predicted_exon->score(),
                    five_prime_overhang => $five_prime_overhang,
                    three_prime_overhang => $three_prime_overhang,
                    transcript_name => $transcript_name,
                    gene_name => $gene_name,
                    sequence_name => $current_seq_name,
                    sequence_string => $exon_seq,
                );
                push @exons, $exon;
            }

            # Create transcript and protein sequence objects
            my $transcript_seq = Bio::Seq->new(
                -seq => $exon_sequence_string,
                -id => $current_seq_name,
            );
            $transcript_seq = $transcript_seq->revcom() if $strand eq '-1';

            # If this sequence is a fragment, need to trim off overhanging sequence prior to translating
            if ($fragment) {
                my $first_exon_overhang = $exons[0]->get_tag_values('five_prime_overhang');
                $first_exon_overhang = $exons[-1]->get_tag_values('five_prime_overhang') if $strand eq '-1';
                $transcript_seq = $transcript_seq->trunc($first_exon_overhang, $transcript_seq->length());
            }

            my $protein_seq = $transcript_seq->translate();

            # Now check the translated sequence for internal stop codons
            my $stop = index($protein_seq->seq(), '*');
            unless ($stop == -1 or $stop == (length($protein_seq->seq()) - 1)) {
                $internal_stops = 1;
            }

            # Now create CodingGene, Transcript, and Protein objects!
            my $coding_gene = EGAP::CodingGene->create(
                file_path => $self->coding_gene_prediction_file,
                gene_name => $gene_name,
                fragment => $fragment,
                internal_stops => $internal_stops,
                missing_start => $missing_start,
                missing_stop => $missing_stop,
                source => $source,
                strand => $strand,
                sequence_name => $current_seq_name,
                start => $start,
                end => $end,
            );

            my $transcript = EGAP::Transcript->create(
                file_path => $self->transcript_prediction_file,
                transcript_name => $transcript_name,
                coding_gene_name => $gene_name,
                start => $start,
                end => $end,
                coding_start => 1,
                coding_end => ($end - $start) + 1,
                sequence_name => $current_seq_name,
                sequence_string => $transcript_seq->seq(),
            );

            my $protein = EGAP::Protein->create(
                file_path => $self->protein_prediction_file,
                protein_name => $transcript_name . "_protein.1",
                internal_stops => $internal_stops,
                fragment => $fragment,
                transcript_name => $transcript_name,
                gene_name => $gene_name,
                sequence_name => $current_seq_name,
                sequence_string => $protein_seq->seq(),
            );
        }
    }

    # TODO add file locking
    UR::Context->commit;
    $self->status_message("Fgenesh parsing complete!");
    return 1;
}

1;
