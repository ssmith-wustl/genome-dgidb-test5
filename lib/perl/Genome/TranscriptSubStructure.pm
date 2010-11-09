package Genome::TranscriptSubStructure;
#:adukes short term: move data directory into id_by, but this has to be done in parallel w/ rewriting all file-based data sources.  It might be better to wait until long term: custom datasource that incorporates data_dir, possibly species/source/version, eliminating the need for these properties in the id, and repeated multiple times in the files


######################################################
#
# NOTE!  This class is probably obsolete.  The annotator (Genome::Transcript::VariantAnnotator)
# uses the new class Genome::TranscriptStructure
#
# ###########################################################################333

use strict;
use warnings;

use Genome;
use Carp;

class Genome::TranscriptSubStructure {
    type_name => 'genome transcript sub structure',
    table_name => 'TRANSCRIPT_SUB_STRUCTURE',
    id_by => [
        transcript_structure_id => { 
            is => 'NUMBER', 
        },
        species => { is => 'varchar',
            is_optional => 1,
        },
        source => { is => 'VARCHAR',
            is_optional => 1,
        },
        version => { is => 'VARCHAR',
            is_optional => 1,
        },
    ],
    has => [
        transcript_id => {  #TODO changed to text extended length
            is => 'Text', 
        },
        structure_type => { 
            is => 'VARCHAR',    
            is_optional => 1 
        },
        structure_start => { 
            is => 'NUMBER', 
            is_optional => 1 
        },
        structure_stop => { 
            is => 'NUMBER', 
            is_optional => 1 
        },
        ordinal => { 
            is => 'NUMBER', 
            is_optional => 1
        },
        phase => { 
            is => 'NUMBER', 
            is_optional => 1
        },
        nucleotide_seq => { 
            is => 'CLOB', 
            is_optional => 1
        },
        transcript => { #TODO, straighten out ID stuff w/ Tony
            is => 'Genome::Transcript', 
            id_by => 'transcript_id' 
        },
        data_directory => {
            is => "Path",
        },
        chrom_name => {
            via => 'transcript',
        },
        gene => {
            via => 'transcript',
        },
        gene_name =>  {
            via => 'gene',
            to => 'name',
        },
        transcript_name => {
            via => 'transcript',
        },
        coding_bases_before => {
            is => 'Text',
            is_optional => 1,
            doc => 'Number of coding exon basepairs before this substructure',
        },
        coding_bases_after => {
            is => 'Text',
            is_optional => 1,
            doc => 'Number of coding exon basepairs after this substructure',
        },
        cds_exons_before => {
            is => 'Text',
            is_optional => 1,
            doc => 'Number of coding exon substructures before this substructure',
        },
        cds_exons_after => {
            is => 'Text',
            is_optional => 1,
            doc => 'Number of coding exon substructures before this substructure',
        },
        phase_bases_before => {
            is => 'Text',
            is_optional => 1,
            doc => 'Any bases that the phase of the exon indicates are needed to complete a codon',
        },
        phase_bases_after => {
            is => 'Text',
            is_optional => 1,
            doc => 'Any bases that the phase of the NEXT exon indicates are needed to complete a codon',
        },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::TranscriptSubStructures',
};

sub length {
    my $self = shift;
    my $length = $self->structure_stop - $self->structure_start + 1;
    return $length;
}

# bdericks: I really don't like this method. Lots of annotation stuff assumes that strand is either
# -1 or +1, and if someone calls structure->strand expecting it to work just like transcript->strand
# they're gonna have some problems.
sub strand {
    my $self = shift;
    my $t = $self->transcript;
    my $strand = '.';
    if ($t->strand eq '+1') {
        $strand = '+';
    } elsif ($t->strand eq '-1') {
        $strand = '-';
    }
    return $strand;
}

sub strand_as_string {
    my $self = shift;
    my $t = $self->transcript;
    my $strand = '.';
    if ($t->strand eq '+1') {
        $strand = 'fwd';
    } elsif ($t->strand eq '-1') {
        $strand = 'rev';
    }
    return $strand;
}


sub frame {
    my $self = shift;
    if (defined($self->phase)) {
        return $self->phase;
    }
    return '.';
}

sub start_with_strand {
    my $self = shift;
    my $start = $self->structure_start;
    $start = $self->structure_stop if $self->transcript->strand eq '-1';
    return $start;
}

sub stop_with_strand {
    my $self = shift;
    my $stop = $self->structure_stop;
    $stop = $self->structure_start if $self->transcript->strand eq '-1';
    return $stop;
}

# Returns the full nucleotide sequence of the structure, including shared bases due to phase
sub full_nucleotide_sequence {
    my $self = shift;
    return unless $self->{structure_type} eq 'cds_exon';
    
    unless (exists $self->{_full_nucleotide_sequence}) {
        my $nucleotide_seq;
        unless ($self->{phase_bases_before} eq 'NULL') {
            $nucleotide_seq .= $self->{phase_bases_before};
        }
        $nucleotide_seq .= $self->{nucleotide_seq};
        unless ($self->{phase_bases_after} eq 'NULL') {
            $nucleotide_seq .= $self->{phase_bases_after};
        }

        $self->{_full_nucleotide_sequence} = $nucleotide_seq;
    }

    return $self->{_full_nucleotide_sequence};
}

# Returns the amino acid at the specified position
sub amino_acid_at_position {
    my ($self, $position) = @_;
    return unless $self->{structure_type} eq 'cds_exon';
    
    my ($codon) = $self->codon_at_position($position);
    return unless defined $codon;
    
    my $transcript = $self->transcript;
    return $transcript->translate_to_aa($codon);
}

# Returns the codon at the specified position and its location within the codon (0-2)
sub codon_at_position {
    my ($self, $position) = @_;
    return unless $self->{structure_type} eq 'cds_exon';
    return unless $position >= $self->{structure_start} and $position <= $self->{structure_stop};

    my $seq = $self->full_nucleotide_sequence;
    my $seq_length = CORE::length $seq;       # Since there's a length method in this package, have
                                              # to explicitly say I want the string length function here
                                              # to avoid a warning about an ambiguous function call
    my ($seq_pos) = $self->sequence_position($position);
    my ($codon, $codon_pos);
    for (my $i = 0; $i <= $seq_length; $i += 3) {
        next unless $seq_pos >= $i and $seq_pos <= $i + 2;
        $codon = substr($seq, $i, 3);
        $codon_pos = $seq_pos - $i;
        last;
    }
    return $codon, $codon_pos;
}   

# Returns the number of bases (not the bases themselves!) this exon borrows from previous exon
sub num_phase_bases_before {
    my $self = shift;
    my $num = 0;
    $num = CORE::length $self->phase_bases_before unless $self->phase_bases_before eq 'NULL';
    return $num;
}

# Same as above, except this method looks at bases borrowed from next exon
sub num_phase_bases_after {
    my $self = shift;
    my $num = 0;
    $num = CORE::length $self->phase_bases_after unless $self->phase_bases_after eq 'NULL';
    return $num;
}

# Given a position, return the position within the structure's coding sequence
# Also returns the number of bases from previous exon used to build the sequence
sub sequence_position {
    my ($self, $position) = @_;
    return unless $self->{structure_type} eq 'cds_exon';

    my $transcript = $self->transcript;
    my $num_borrowed = $self->num_phase_bases_before;

    my $seq_start;
    $seq_start = $self->structure_start if $transcript->strand eq '+1';
    $seq_start = $self->structure_stop if $transcript->strand eq '-1';

    my $seq_position = $num_borrowed + abs($seq_start - $position);

    return $seq_position, $num_borrowed;
}

# Given a position, determine the distance between the position and the structure's stranded start
# The start here accounts for strand, so if transcript is reverse stranded then the structure start
# is GREATER than the structure stop
sub distance_to_start {
    my ($self, $position) = @_;
    my $structure_start = $self->structure_start;
    my $structure_stop = $self->structure_stop;
    my $strand = $self->transcript->strand;
    ($structure_start, $structure_stop) = ($structure_stop, $structure_start) if $strand eq '-1';

    return abs($position - $structure_start);
}

# Given a position, determine the distance between the position and the structure's stranded stop
sub distance_to_stop {
    my ($self, $position) = @_;
    my $structure_start = $self->structure_start;
    my $structure_stop = $self->structure_stop;
    my $strand = $self->transcript->strand;
    ($structure_start, $structure_stop) = ($structure_stop, $structure_start) if $strand eq '-1';

    return abs($position - $structure_stop);
}

# Given a start and stop and the number of extra codons to include, get the codons within the range
# start - stop and include X extra codons on either side. If the codon sequence hits the start or stop
# of the structure, then include X codons from the previous or next exon
sub codons_in_range {
    my ($self, $orig_start, $orig_stop, $extra) = @_;
    return unless $self->structure_type eq 'cds_exon';

    my $seq = $self->full_nucleotide_sequence;
    my $seq_length = CORE::length $seq;

    # Relative start and stop record the position within this structure's sequence that
    # the original start and stop correspond to. This is necessary to allow for the variant sequence
    # to be properly stuck into the codon sequence later on
    my $relative_start = $orig_start - $self->structure_start;
    my $relative_stop = $orig_stop - $self->structure_start;


    # If reverse strand, then the sequence is already reverse complemented. However, the start
    # and stop positions (which are originally relative to the structure start and stop) need to be
    # reversed so that start counts up from structure stop.
    if ($self->transcript->strand eq '-1') {
        $relative_start = $seq_length - $relative_start - 1;
        $relative_stop = $seq_length - $relative_stop - 1;
        ($relative_start, $relative_stop) = sort {$a <=> $b} ($relative_start, $relative_stop);
        $relative_start -= $self->num_phase_bases_after;
        $relative_stop -= $self->num_phase_bases_after;
    }
    else {
        $relative_start += $self->num_phase_bases_before;
        $relative_stop += $self->num_phase_bases_before;
    }

    # The extra start and stop record where the substring of the structure sequence should start
    # and stop, including all the extra codons from neighboring exons and so forth that get tacked on
    # These are used later when the substring of interest is removed from the structure sequence
    my $extra_start = $relative_start;
    my $extra_stop = $relative_stop;
    my $codon_pos_start = $extra_start % 3;
    my $codon_pos_stop = $extra_stop % 3;

    # Add extra codons to either side of range and use codon position to make sure that no partial codons are added
    $extra_start -= (($extra * 3) + $codon_pos_start);
    $extra_start = 0 if $extra_start < 0;
    $extra_stop += (($extra * 3) + (2 - $codon_pos_stop));    # Since codon position is 0-based, use 2 here instead of 3
                                                              # to determine how many bases remain in the codon
    $extra_stop = $seq_length - 1 if $extra_stop >= $seq_length;

    # Add sequence from previous exon (previous = 5', not necessarily the one that had lower position!) and
    # update relative start and stop so they still point at proper position. Extra stop is incremented so that
    # range extra_start <-> extra_stop is increased to include extra sequence
    if ($extra_start == 0) {
        my $prev_structure_seq = $self->last_codons_of_previous_exon($extra);
        if (defined $prev_structure_seq) {
            my $prev_seq_length = CORE::length $prev_structure_seq;
            $relative_start += $prev_seq_length;
            $relative_stop += $prev_seq_length;
            $extra_stop += $prev_seq_length;
            $seq = $prev_structure_seq . $seq;
        }
    }

    # Add sequence from next exon
    if ($extra_stop == ($seq_length - 1)) {
        my $next_structure_seq = $self->first_codons_of_next_exon($extra);
        if (defined $next_structure_seq) {
            my $next_seq_length = CORE::length $next_structure_seq;
            $seq .= $next_structure_seq;
            $extra_stop += $next_seq_length;
        }
    }

    my $codons = substr($seq, $extra_start, $extra_stop - $extra_start + 1);

    # Now reset values of relative start and stop so they apply to new (smaller) substring of structure sequence
    $relative_start = $relative_start - $extra_start + 1;
    $relative_stop = $relative_stop - $extra_start + 1;

    return $codons, $relative_start, $relative_stop;
}

# Finds and returns the last X codons of the previous structure, previous in this
# sense meaning 5' (so, the previous exon would be the one that was transcribed before
# this one!)
sub last_codons_of_previous_exon {
    my ($self, $num_codons) = @_;
    return unless $self->structure_type eq 'cds_exon';
    return if $self->ordinal == 1;

    my $transcript = $self->transcript;
    my $seq_obj = Genome::TranscriptCodingSequence->get(
        data_directory => $transcript->data_directory,
        transcript_id => $transcript->id,
    );
    return unless $seq_obj;
    my $seq = $seq_obj->sequence;
 
    my $bases_before = $self->coding_bases_before;
    $bases_before -= $self->num_phase_bases_before;  # Don't want to count shared phase bases twice
    return if $bases_before == 0;
    my $bases_to_borrow = $num_codons * 3;
    $bases_to_borrow =  $bases_before if $bases_before < $bases_to_borrow;

    my $prev_seq = substr($seq, 0, $bases_before);
    $prev_seq = substr($prev_seq, -($bases_to_borrow));
    return $prev_seq;
}

# Finds and returns the first X codons of the next structure (next reliant on strand,
# not general position
sub first_codons_of_next_exon {
    my ($self, $num_codons) = @_;
    return unless $self->structure_type eq 'cds_exon';
    return if $self->coding_bases_after == 0;

    my $transcript = $self->transcript;
    my $seq_obj = Genome::TranscriptCodingSequence->get(
        data_directory => $transcript->data_directory,
        transcript_id => $transcript->id,
    );
    return unless $seq_obj;
    my $seq = $seq_obj->sequence;

    my $bases_before = $self->coding_bases_before;
    my $structure_length = $self->length;
    my $num_phase_bases = $self->num_phase_bases_after;
    my $total_prior_bases = $bases_before + $structure_length + $num_phase_bases;
    my $remaining_bases = (CORE::length $seq) - $total_prior_bases;
    
    my $bases_to_borrow = $num_codons * 3;
    $bases_to_borrow = $remaining_bases if $remaining_bases < $bases_to_borrow;

    my $next_seq = substr($seq, $total_prior_bases, $bases_to_borrow);
    return $next_seq;
}

sub bed_string {
    my $self = shift;
    # BED format uses zero-based start positions
    my $bed_string = $self->chrom_name ."\t". ($self->structure_start - 1) ."\t". $self->structure_stop ."\t". $self->gene_name .':'. $self->transcript_name
    .':'. $self->structure_type .":". $self->ordinal .':'. $self->strand_as_string ."\t0\t". $self->strand ."\n";
    return $bed_string;
}

sub _base_gff_string {
    my $self = shift;
    return $self->chrom_name ."\t". $self->source .'_'. $self->version ."\t". $self->structure_type ."\t". $self->structure_start ."\t". $self->structure_stop ."\t.\t". $self->strand ."\t". $self->frame;
}

sub gff_string {
    my $self = shift;
    return $self->_base_gff_string ."\t". $self->gene_name ."\n";
}

sub gff3_string {
    my $self = shift;
    return $self->_base_gff_string ."\tID=". $self->transcript_structure_id .'; PARENT='. $self->transcript->transcript_id .';' ."\n";
}

sub gtf_string {
    return undef;
}

1;

#TODO
=pod
=cut
