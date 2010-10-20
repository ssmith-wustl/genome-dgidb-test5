package EGAP::Command::GenePredictor::SNAP;

use strict;
use warnings;

use EGAP;
use English;
use File::Temp;
use Carp 'confess';
use File::Path 'make_path';

class EGAP::Command::GenePredictor::SNAP {
    is  => 'EGAP::Command::GenePredictor',
    has => [
        model_files => {
            is => 'Text',
            is_input => 1,
            doc => 'A list of snap model files, delimited by commas',
        },
    ],
    has_optional => [
        version => {
            is => 'String',
            is_input => 1,
            valid_values => ['2004-06-17', '2007-12-18', '2010-07-28'],
            default => '2010-07-28',
        },        
    ],
};

sub help_brief {
    return "Runs the SNAP gene predictor on provided sequence";
}

sub help_synopsis {
    return "Runs the SNAP gene predictor on provided sequence";
}

sub help_detail {
    return <<EOS
Runs the SNAP gene predictor and places raw output in a temp file in the
provided raw output directory. Raw output is parsed and RNAGene objects
are created and commited to the provided output file.
EOS
}

# TODO This is a bit of a long mess, refactoring may be in order both to make this more
# readable and to reduce redundancy between this module and the fgenesh module.
sub execute {
    my $self = shift;
    $self->status_message("Starting SNAP prediction wrapper");

    # Use full path to snap executable, with version, instead of the symlink.
    # This prevents the symlink being changed silently and affecting our output!
    my $snap_path = "/gsc/pkg/bio/snap/snap-" . $self->version . "/snap";

    unless (-d $self->raw_output_directory) {
        my $mkdir_rv = make_path($self->raw_output_directory);
        confess "Could not make directory " . $self->raw_output_directory unless $mkdir_rv;
    }

    my $raw_output_fh = File::Temp->new(
        DIR => $self->raw_output_directory,
        TEMPLATE => 'snap_raw_output_XXXXXX',
        CLEANUP => 0,
        UNLINK => 0,
    );
    my $raw_output = $raw_output_fh->filename;
    $raw_output_fh->close;

    my $raw_error_fh = File::Temp->new(
        DIR => $self->raw_output_directory,
        TEMPLATE => 'snap_raw_output_XXXXXX',
        CLEANUP => 0,
        UNLINK => 0,
    );
    my $raw_error = $raw_error_fh->filename;
    $raw_error_fh->close;

    my @models = split(",", $self->model_files);
    confess 'Received no SNAP models, not running predictor!' unless @models;
    $self->status_message("Running SNAP " . scalar @models . " times with different model files!");

    # Construct SNAP command and execute for each supplied model file
    for my $model (@models) {
        unless (-e $model) {
            confess "No SNAP model found at $model!"
        }

        my @params;
        push @params, '-quiet';
        push @params, $model;
        push @params, $self->fasta_file;
        push @params, ">> $raw_output";
        push @params, "2>> $raw_error";
        my $cmd = join(' ', $snap_path, @params);

        $self->status_message("Executing SNAP command: $cmd");
        my $rv = system($cmd);
        confess "Trouble executing SNAP!" unless defined $rv and $rv == 0;
    }

    $self->status_message('Done running SNAP, now parsing output and creating prediction objects');

    my $snap_fh = IO::File->new($raw_output, "r");
    unless ($snap_fh) {
        confess "Could not open " . $raw_output . ": $OS_ERROR";
    }

    my @predicted_exons;
    my $gene_count = 0;
    my ($current_seq_name, $current_group, $seq_obj);

    # SNAP output is grouped by sequence name. Each line of output is an exon, and these exons are grouped into genes. If 
    # a line starts with a >, this indicates a new sequence's predictions come next, so any exons we've recorded for the
    # current sequence need to be made into objects. If the group name differs from the previous line's, this indicates
    # that a new gene is starting and prediction objects need to be made.
    while (my $line = <$snap_fh>) {
        chomp $line;
        if ($line =~ /^>(.+)$/) {
            if (@predicted_exons) {
                $self->_create_prediction_objects(\@predicted_exons, $gene_count, $current_seq_name, $current_group, $seq_obj);
                $gene_count++;
                @predicted_exons = ();
            }

            $current_seq_name = $1;
            $seq_obj = $self->get_sequence_by_name($current_seq_name);
            confess "Couldn't get sequence $current_seq_name!" unless $seq_obj;
            $self->status_message("Parsing predictions from $current_seq_name");
        }
        else {
            my (
                $label,
                $begin,
                $end,
                $strand,
                $score,
                $five_prime_overhang,
                $three_prime_overhang,
                $frame,
                $group
            ) = split /\t/, $line;

            if (defined $current_group and $current_group ne $group and @predicted_exons) {
                $self->_create_prediction_objects(\@predicted_exons, $gene_count, $current_seq_name, $current_group, $seq_obj);
                $gene_count++;
                @predicted_exons = ();
            }

            $current_group = $group;

            # Each line of output from SNAP is an exon. Can't create "larger" objects like genes, trancripts, and proteins
            # until all the exons of a group are available.
            my %exon_hash = (
                sequence_name => $current_seq_name,
                start => $begin,
                end => $end,
                strand => $strand,
                score => $score,
                source => 'SNAP',
                exon_type => $label,
                five_prime_overhang => $five_prime_overhang,
                three_prime_overhang => $three_prime_overhang,
                frame => $frame,
            );
            push @predicted_exons, \%exon_hash;
        }
    }
    $self->_create_prediction_objects(\@predicted_exons, $gene_count, $current_seq_name, $current_group, $seq_obj);

    my @locks = $self->lock_files_for_predictions(qw/ EGAP::CodingGene EGAP::Protein EGAP::Transcript EGAP::Exon /);
    UR::Context->commit;
    $self->release_prediction_locks(@locks);

    $self->status_message("Successfully finished parsing SNAP output and creating prediction objects!");
    return 1;
}

sub _create_prediction_objects {
    my ($self, $predicted_exons, $gene_count, $current_seq_name, $current_group, $seq_obj) = @_;
    my @predicted_exons = sort { $a->{start} <=> $b->{start}} @{$predicted_exons};
    my $start = $predicted_exons[0]->{start};
    my $end = $predicted_exons[-1]->{end};
    my $strand = $predicted_exons[0]->{strand};
    my $source = $predicted_exons[0]->{source};
    my $gene_name = join('.', $current_seq_name, $source, $gene_count);
    my $transcript_name = $gene_name . '.1';
    my $protein_name = $transcript_name . "_protein.1";

    # Check that we have all the exons we expect.
    # If there is only one exon, it has label Esngl. For more than one exon, the first should be 
    # Einit and the last should be Eterm, and those in the middle should be Exon. Not following
    # this pattern gets a flag set on the gene
    my ($fragment, $internal_stops, $missing_start, $missing_stop) = (0,0,0,0);
    if (@predicted_exons > 1) {
        my $first_exon_type = $predicted_exons[0]->{exon_type};
        my $last_exon_type = $predicted_exons[-1]->{exon_type};

        # These are sorted by position, not strand, which is why we have to check both the first and last exon
        unless ($first_exon_type eq 'Einit' or $last_exon_type eq 'Einit') {
            $missing_start = 1;
            $fragment = 1;
        }
        unless ($first_exon_type eq 'Eterm' or $last_exon_type eq 'Eterm') {
            $missing_stop = 1;
            $fragment = 1;
        }
    }
    else {
        my $exon_type = $predicted_exons[0]->{exon_type};
        if ($exon_type ne 'Esngl') {
            $fragment = 1;
            if ($exon_type ne 'Einit') {
                $missing_start = 1;
            }
            if ($exon_type ne 'Eterm') {
                $missing_stop = 1;
            }
        }
    }

    # Create EGAP::Exon objects for each predicted exon and construct exon sequence string
    my $exon_seq_string;
    my @exons;
    my $exon_count = 0;
    for my $predicted_exon (@predicted_exons) {
        my $exon_name = $transcript_name . ".exon.$exon_count";
        $exon_count++;

        my $exon_seq = $seq_obj->subseq($predicted_exon->{start}, $predicted_exon->{end});
        $exon_seq_string .= $exon_seq;

        my $exon = EGAP::Exon->create(
            directory => $self->prediction_directory,
            exon_name => $exon_name,
            start => $predicted_exon->{start},
            end => $predicted_exon->{end},
            strand => $predicted_exon->{strand},
            score => $predicted_exon->{score},
            five_prime_overhang => $predicted_exon->{five_prime_overhang},
            three_prime_overhang => $predicted_exon->{three_prime_overhang},
            transcript_name => $transcript_name,
            gene_name => $gene_name,
            sequence_name => $current_seq_name,
            sequence_string => $exon_seq,
        );
        push @exons, $exon;
    }

    my $transcript_seq = Bio::Seq->new(
        -id => $transcript_name,
        -seq => $exon_seq_string,
    );
    $transcript_seq = $transcript_seq->revcom() if $strand eq '-1';

    # If this sequence is a fragment, need to trim off overhanging sequence prior to translating
    if ($fragment) {
        my $first_exon_overhang = $exons[0]->five_prime_overhang;
        $first_exon_overhang = $exons[-1]->five_prime_overhang if $strand eq '-1';
        $first_exon_overhang++;  # Start is not 0-based, passing in zero results in a BioPerl exception
        $transcript_seq = $transcript_seq->trunc($first_exon_overhang, $transcript_seq->length());
    }

    my $protein_seq = $transcript_seq->translate();

    # Now check the translated sequence for internal stop codons
    my $stop = index($protein_seq->seq(), '*');
    unless ($stop == -1 or $stop == (length($protein_seq->seq()) - 1)) {
        $internal_stops = 1;
    }

    # Finally have all the information needed to create gene, protein, and transcript objects
    my $coding_gene = EGAP::CodingGene->create(
        directory => $self->prediction_directory,
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
        directory => $self->prediction_directory,
        transcript_name => $transcript_name,
        coding_gene_name => $gene_name,
        start => $start,
        end => $end,
        coding_start => 1,
        coding_end => ($end - $start) + 1,
        sequence_name => $current_seq_name,
        sequence_string => $transcript_seq->seq(),
        protein_name => $protein_name,
    );

    my $protein = EGAP::Protein->create(
        directory => $self->prediction_directory,
        protein_name => $protein_name,
        internal_stops => $internal_stops,
        fragment => $fragment,
        transcript_name => $transcript_name,
        gene_name => $gene_name,
        sequence_name => $current_seq_name,
        sequence_string => $protein_seq->seq(),
    );

    return 1;
}

1;
