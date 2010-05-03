package Genome::Transcript;
#:adukes short term: move data directory into id_by, but this has to be done in parallel w/ rewriting all file-based data sources.  It might be better to wait until long term: custom datasource that incorporates data_dir, possibly species/source/version, eliminating the need for these properties in the id, and repeated multiple times in the files

use strict;
use warnings;

use Genome;
use Genome::Info::AnnotationPriorities;
use Bio::Tools::CodonTable;

class Genome::Transcript {
    type_name => 'genome transcript',
    table_name => 'TRANSCRIPT',
    id_by => [
        chrom_name => { 
            is => 'Text', 
        },
        transcript_start => { 
            is => 'NUMBER', 
            is_optional => 1 
        },
        transcript_stop => { 
            is => 'NUMBER', 
            is_optional => 1,
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
        transcript_id => { 
            is => 'NUMBER', 
        },
    ],
    has => [
        gene_id => { 
            is => 'Text', 
        },
        transcript_name => { 
            is => 'VARCHAR', 
            is_optional => 1,
        },
        transcript_status => { is => 'VARCHAR',
            is_optional => 1,
            valid_values => ['reviewed', 'unknown', 'model', 'validated', 'predicted', 'inferred', 'provisional', 'unknown', 'known', 'novel'],
        },
        strand => { is => 'VARCHAR',
            is_optional => 1,
            valid_values => ['+1', '-1', 'UNDEF'],
        },
        sub_structures => { 
            calculate_from => [qw/ id  data_directory/],
            calculate => q|
            Genome::TranscriptSubStructure->get(transcript_id => $id, data_directory => $data_directory);
            |,
        },
        protein => { 
            calculate_from => [qw/ id data_directory/],
            calculate => q|
            Genome::Protein->get(transcript_id => $id, data_directory => $data_directory);
            |,
        },
        gene => {
            calculate_from => [qw/ gene_id data_directory/],
            calculate => q|
            Genome::Gene->get(id => $gene_id, data_directory => $data_directory);
            |,
        },
        data_directory => {
            is => "Path",
        },

    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::Transcripts',
};

# Returns the start position or a dummy negative value to prevent annotation if not defined
sub transcript_start {
    my $self = shift;
    my $start = $self->__transcript_start;
    return $start if $start;
    $self->status_message("undefined start for transcript (chrom\tstart\tid):(". $self->id.") ".$self->transcript_name.".  Returning -100000 to avoid annotation");
    return -100000;
}

# Returns the stop position or a dummy negative value to prevent annotation if not defined
sub transcript_stop {
    my $self = shift;
    my $stop = $self->__transcript_stop;
    return $stop if $stop;
    $self->status_message("undefined stop for transcript (chrom\tstart\tid):(". $self->id.") ".$self->transcript_name.".  Returning -100000 to avoid annotation");
    return -100000;
}

# Returns the transcript substructure (if any) that are at the given position
sub structure_at_position {
    my ($self, $position) = @_;

    # check if in range of the trascript
    my @structures = $self->ordered_sub_structures;
    unless (@structures){
        $self->status_message("No sub-structures for transcript (chrom\tstart\tid):(". $self->id.") ".$self->transcript_name);
        return;
    }
    return unless $structures[0]->structure_start <= $position
        and $structures[$#structures]->structure_stop >= $position;

    # get the sub structure
    for my $struct ( @structures ) {
        return $struct if $position >= $struct->structure_start
            and $position <= $struct->structure_stop;
    }

    $self->status_message("No substructure found for transcript " . $self->id . " at position " . $position);
    return;
}

# Returns the transcript substructures (if any) that are between the given start and stop position
sub structures_in_range {
    my ($self, $start, $stop) = @_;

    my @structures = $self->ordered_sub_structures;
    unless (@structures){
        $self->status_message("No substructures for transcript (chrom\tstart\tid):(" . $self->id. ") " . $self->transcript_name);
        return;
    }

    if (($structures[0]->structure_start > $stop) or ($structures[$#structures]->structure_stop < $start)){
        return;
    }

    my @structures_in_range;
    for my $structure (@structures){
        my $ss_start = $structure->structure_start;
        my $ss_stop = $structure->structure_stop;
        if (($ss_start >= $start and $ss_start <= $stop ) or 
            ($ss_stop >= $start and $ss_stop <= $stop ) or
            ($ss_start <= $start and $ss_stop >=$stop )
        ){
            push @structures_in_range, $structure;
        }
    }
    return @structures_in_range;
}

# Gets the structure at the specified position and returns the structure(s) on either side of it
sub structures_flanking_structure_at_position {
    my ($self, $position) = @_;

    # check if in range of the transcript
    my @structures = $self->ordered_sub_structures;
    return unless $structures[0]->structure_start <= $position
        and $structures[$#structures]->structure_stop >= $position;

    my $structure_index = 0;
    for my $struct ( @structures ) {
        last if $position >= $struct->structure_start
            and $position <= $struct->structure_stop;
        $structure_index++;
    }

    return ( $structure_index == 0 ) # don't return [-1], last struct!
    ? (undef, $structures[1])
    : (
        $structures[ $structure_index - 1 ],
        $structures[ $structure_index + 1 ],
    );
}

# Returns all transcript substrucuters ordered by position
sub ordered_sub_structures {
    my $self = shift;

    unless ($self->{_ordered_sub_structures}) {
        my @subs = sort { $a->structure_start <=> $b->structure_start } $self->sub_structures;
        $self->{_ordered_sub_structures} = \@subs;
    }
    return @{$self->{_ordered_sub_structures}};
}

# Returns codon table object 
sub get_codon_translator {
    my $self = shift;
    my $translator;
    if ($self->chrom_name =~ /^MT/){
        $translator = $self->{'_mitochondrial_codon_translator'};
        unless ($translator) {
            $translator = Bio::Tools::CodonTable->new(-id => 2);
        }
    }
    else {
        $translator = $self->{'_codon_translator'};
        unless ($translator) {
            $translator = Bio::Tools::CodonTable->new(-id => 1);
        }
    }
    
    unless ($translator) {
        $self->error_message("Could not get codon table object");
        die;
    }
    
    return $translator;
}

# Performs a few checks on the transcript to determine if its valid
# Sets the error attribute to the number listed in Genome::Info::AnnotationPriorities
sub is_valid {
    my $self = shift;
    unless ($self->check_start_codon) {
        $self->{transcript_error} = 'no_start_codon';
        return 0;
    }
    unless ($self->internal_stop_codon) {
        $self->{transcript_error} = 'pseudogene';
        return 0;
    }
    unless ($self->cds_region_has_stop_codon) {
        $self->{transcript_error} = 'no_stop_codon';
        return 0;
    }
    $self->{transcript_error} = 'no_errors';
    return 1;
}

# Checks that the transcript has a coding region
sub has_cds_region {
    my $self = shift;
    return 1 if $self->is_rna;
    my $seq = $self->cds_full_nucleotide_sequence;
    return 1 if defined $seq and length $seq > 0;
    return 0;
}

# Checks if the transcript represents rna
sub is_rna {
    my $self = shift;
    my @subs = $self->sub_structures;
    for my $sub (@subs) {
        return 1 if $sub->structure_type eq 'rna';
    }
    return 0;
}

# Checks that the transcript has an associated gene
sub has_associated_gene {
    my $self = shift;
    my $gene = $self->gene;
    return 0 unless defined $gene;
    return 1;
}

# Checks that the transcript has either +1 or -1 for strand
sub has_valid_strand {
    my $self = shift;
    my $strand = $self->strand;
    return 1 if $strand eq '+1' or $strand eq '-1';
    return 0;
}

# Translates basepair sequence into amino acid sequence
sub translate_to_aa {
    my $self = shift;
    my $seq = shift;
    my $length = length $seq;
    my $translator = $self->get_codon_translator;
    my $translation;
    for (my $i=0; $i<=$length-2; $i+=3) {
        my $codon=substr($seq, $i, 3);
        $codon =~ s/N/X/g;
        my $aa = $translator->translate($codon);
        $aa="*" if ($aa eq 'X');
        $translation.=$aa;
    }
    return $translation;
}

# Compares the protein aa sequence with the transcript's translated aa sequence
sub transcript_translation_matches_aa_seq {
    my $self = shift;
    my $protein_aa_seq = $self->protein->amino_acid_seq;
    my $transcript_translation = $self->translate_to_aa($self->cds_full_nucleotide_sequence);
    unless ($protein_aa_seq eq $transcript_translation) {
        return 0;
    }
    return 1;
}

# Make sure that coding region starts with a start codon
sub check_start_codon {
    my $self = shift;

    return 1 if $self->is_rna;                 # Rna doesn't have a coding region, and so doesn't have a start codon
    return 1 unless $self->species eq 'human'; # Start codon check only works for human

    my $seq = $self->cds_full_nucleotide_sequence;
    return 1 unless defined $seq;

    my $translator = $self->get_codon_translator;
    return $translator->is_start_codon(substr($seq, 0, 3))
}

# Checks that all exons (coding and untranslated) and introns are contiguous
sub substructures_are_contiguous {
    my $self = shift;
    my @ss = $self->ordered_sub_structures;
    my $stop_position;
    my $last_ss_type;
    while (my $ss = shift @ss){
        if ($stop_position){
            return 0 unless $ss->structure_start == $stop_position + 1;
            $stop_position = $ss->structure_stop;
        }else{
            $stop_position = $ss->structure_stop;
        }
    }
    return 1;
}

# Ensures that no introns are larger than 900kb
sub check_intron_size {
    my $self = shift;
    my @introns = $self->introns;
    foreach my $intron (@introns) {
        return 0 if $intron->length > 900000 
    } 
    return 1;
}

# Checks that each exon's nucleotide sequence matches the reference sequence
sub exon_seq_matches_genome_seq {
    my $self = shift;
    my @exons = $self->cds_exons;
    foreach my $exon (@exons) {
        my $ref_seq = Genome::Model::Tools::ImportAnnotation::Genbank->get_seq_slice(
            $self->chrom_name, $exon->structure_start, $exon->structure_stop
        );
        my $exon_seq = $exon->nucleotide_seq;
        return 0 unless $ref_seq eq $exon_seq;
    }
    return 1;
}

# Ensures that the coding region has a stop codon at the end
sub cds_region_has_stop_codon {
    my $self = shift;

    return 1 if $self->is_rna;

    my $seq = $self->cds_full_nucleotide_sequence;
    return 1 unless defined $seq and length $seq > 0;

    my $aa = $self->translate_to_aa($seq);
    if (substr($aa, -1) eq "*") {
        return 1;
    }
    else {
        return 0;
    }
}

# Checks for stop codons in the middle of the coding region
sub internal_stop_codon {
    my $self = shift;

    return 1 if $self->is_rna;

    my $seq = $self->cds_full_nucleotide_sequence;
    return 1 unless defined $seq and length $seq > 0;

    my $aa = $self->translate_to_aa($seq);
    my $stop = index($aa, "*");
    unless ($stop == -1 or $stop == length($aa) - 1) {
        return 0;
    }
    return 1;
}

# Checks that the coding region base pairs are correctly grouped into 3bp codons
sub correct_bp_length_for_exons {
    my $self = shift;
    my $seq = $self->cds_full_nucleotide_sequence;
    return 1 unless defined $seq;
    if ($self->chrom_name =~ /^MT/) {
        return 1 if length $seq % 3 == 2;
    }
    return 1 if length $seq % 3 == 0;
    return 0;
}

# Returns all coding exons associated with this transcript
sub cds_exons {
    my $self = shift;

    my @ex = grep { $_->structure_type eq 'cds_exon' } $self->ordered_sub_structures;
    return @ex;
}

# Returns all introns associated with this transcript
sub introns {
    my $self = shift;

    my @int = grep { $_->structure_type eq 'intron' } $self->ordered_sub_structures;
    return @int;
}

# Returns the start position of the first exon and the stop position the last exon on the transcript
sub cds_exon_range {
    my $self = shift;

    my @cds_exons = $self->cds_exons
        or return;

    return ($cds_exons[0]->structure_start, $cds_exons[$#cds_exons]->structure_stop);
}

# Determines structure at given position and returns the range of coding exons before it
sub length_of_cds_exons_before_structure_at_position { #TODO, clean this up, shouldn't take strand should use transcript strand and exon ordinality
    my ($self, $position, $strand) = @_;

    my @cds_exons = $self->cds_exons
        or return;

    my $structure = $self->structure_at_position($position);
    $strand = '+1' unless $strand;

    # Make this an anon sub for slight speed increase
    my $exon_is_before;
    if ( $strand eq '+1' ) {
        my $structure_start = $structure->structure_start;
        $exon_is_before = sub {
            return $_[0]->structure_stop < $structure_start;
        }
    }
    else {
        my $structure_stop = $structure->structure_stop;
        $exon_is_before = sub {
            return $_[0]->structure_start > $structure_stop;
        }
    }

    my $length = 0;
    foreach my $cds_exon ( @cds_exons ) {
        next unless $exon_is_before->($cds_exon);
        $length += $cds_exon->structure_stop - $cds_exon->structure_start + 1;
    }

    return $length;
}

# Grab only those coding exons that have ordinal defined
sub cds_exon_with_ordinal {
    my ($self, $ordinal) = @_;

    foreach my $cds_exon ( $self->cds_exons ) {
        return $cds_exon if $cds_exon->ordinal == $ordinal;
    }

    return;
}

# Full base pair sequence of coding regions
sub cds_full_nucleotide_sequence{
    my $self = shift;
    my $seq;
    foreach my $cds_exon ( sort { $a->ordinal <=> $b->ordinal} $self->cds_exons ) {
        $seq.= $cds_exon->nucleotide_seq;
    }
    return $seq;
}


# Returns name of associated gene
sub gene_name
{
    my $self = shift;

    my $gene = $self->gene;
    my $gene_name = $gene->name($self->source);;

    return $gene_name;
}

# Returns strand as either + or - (used for bed string below)
sub strand_string {
    my $self = shift;
    my $strand = '.';
    if ($self->strand eq '+1') {
        $strand = '+';
    } elsif ($self->strand eq '-1') {
        $strand = '-';
    }
    return $strand;
}

# Returns string containing transcript info in bed format
sub bed_string {
    my $self = shift;
    my $bed_string = $self->chrom_name ."\t". $self->transcript_start ."\t". $self->transcript_stop ."\t". $self->transcript_name ."\t0\t". $self->strand_string;
    return $bed_string ."\n";
}

# Base string for gff format
sub _base_gff_string {
    my $self = shift;
    return $self->chrom_name ."\t". $self->source .'_'. $self->version ."\t". 'transcript' ."\t". $self->transcript_start ."\t". $self->transcript_stop ."\t.\t". $self->strand_string ."\t.";
}

# Returns string containing transcript info in gff file format
sub gff_string {
    my $self = shift;
    return $self->_base_gff_string ."\t". $self->gene->name ."\n";
}

# Returns string containing transcript info in gff3 file format
sub gff3_string {
    my $self = shift;
    return $self->_base_gff_string ."\tID=".$self->transcript_id ."; NAME=". $self->transcript_name ."; PARENT=". $self->gene->gene_id .';' ."\n";
}

sub gtf_string {
    my $self = shift;
    my @sub_structure = grep {$_->structure_type ne 'flank'} $self->ordered_sub_structures;
    my %exon_sub_structures;
    for my $ss (@sub_structure){
        push @{$exon_sub_structures{$ss->ordinal}}, $ss;
    }
    my $string;
    for my $ordinal ( sort {$a <=> $b} keys %exon_sub_structures ) {
        my @cds_strings;
        my $exon_start;
        my $exon_stop;
        my $exon_strand;
        for my $ss (@{$exon_sub_structures{$ordinal}}) {
            my $type = $ss->structure_type;
            if ($type =~ /intron/ || $type =~ /flank/) {
                next;
            } elsif ($type eq 'cds_exon') {
                $type = 'CDS';
                push @cds_strings, $ss->chrom_name ."\t". $ss->source .'_'. $ss->version ."\t". $type ."\t". $ss->structure_start ."\t". $ss->structure_stop ."\t.\t". $ss->strand ."\t". $ss->frame ."\t".' gene_id "'. $ss->gene_name .'"; transcript_id "'. $ss->transcript_name .'"; exon_number "'. $ordinal .'";';
            }
            unless ($exon_start && $exon_stop) {
                $exon_start = $ss->structure_start;
                $exon_stop = $ss->structure_stop;
                $exon_strand = $ss->strand;
            } else {
                if ($ss->structure_start < $exon_start) {
                    # Should never happen since ss are ordered
                    $exon_start = $ss->structure_start;
                }
                if ($ss->structure_stop > $exon_stop) {
                    $exon_stop = $ss->structure_stop;
                }
                if ($ss->strand ne $exon_strand) {
                    #This should never happen
                    die('Inconsistent strand on transcript '. $self->transcript_name);
                }
            }
        }
        $string .= $self->chrom_name ."\t". $self->source .'_'. $self->version ."\texon\t". $exon_start ."\t". $exon_stop ."\t.\t". $exon_strand ."\t.\t".' gene_id "'. $self->gene->name .'"; transcript_id "'. $self->transcript_name .'"; exon_number "'. $ordinal .'";' ."\n";
        if (scalar(@cds_strings)) {
            $string .= join("\n", @cds_strings) ."\n";
        }
    }
    return $string;
}

1;

#TODO
=pod


=cut

