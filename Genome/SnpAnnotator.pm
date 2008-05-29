package Genome::SnpAnnotator;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use Genome::Info::CodonToAminoAcid;
use Genome::Info::VariantPriorities;

my %trans_win :name(transcript_window:r) :isa('object');
my %var_win :name(variation_window:r) :isa('object');

my %variant_priorities = Genome::Info::VariantPriorities->for_annotation;
my %codon2single = Genome::Info::CodonToAminoAcid->single_letter;

sub STARTT
{
    #TODO create a anon sub to run the process to only get the info desired
    my $self = shift;

    return 1;
}

sub get_annotations
{
    my ($self, %snp) = @_;

    my @transcripts_to_annotate = $self->_determine_transcripts_to_annotate($snp{position})
        or return;
    
    my @annotations;
    foreach my $transcript ( @transcripts_to_annotate )
    {
        my %annotation = $self->_transcript_annotation($transcript, \%snp)
            or next;
        $annotation{c_position} = 'c.' . $annotation{c_position};
        $annotation{variations} = $self->_variation_sources(\%snp);
        push @annotations, \%annotation;
    }

    return @annotations;
}

sub get_prioritized_annotations
{
    my ($self, %snp) = @_;
    
    my @annotations = $self->get_annotations(%snp)
        or return;

    my %prioritized_annotations;
    foreach my $annotation ( @annotations )
    {
        $annotation->{priority} = $variant_priorities{ $annotation->{trv_type} };
        unless ( exists $prioritized_annotations{ $annotation->{gene_name} } )
        {
            $prioritized_annotations{ $annotation->{gene_name} } = $annotation;
        }
        elsif ( $annotation->{priority} < $prioritized_annotations{ $annotation->{gene_name} }->{priority} )
        {
            $prioritized_annotations{ $annotation->{gene_name} } = $annotation;
        }
        elsif ( $annotation->{priority} == $prioritized_annotations{ $annotation->{gene_name} }->{priority} )
        {
            next if $annotation->{amino_acid_length} < $prioritized_annotations{ $annotation->{gene_name} }->{amino_acid_length};
            $prioritized_annotations{ $annotation->{gene_name} } = $annotation;
        }
    }
        
    return values %prioritized_annotations;
}

sub _determine_transcripts_to_annotate
{
    my ($self, $position) = @_;

    my (@transcripts_priority_1, @transcripts_priority_2);
    foreach my $transcript ( $self->transcript_window->scroll($position) )
    {
        if ( grep { $transcript->transcript_status eq $_ } (qw/ known reviewed validated /) )
        {
            push @transcripts_priority_1, $transcript;
        }
        elsif ( $transcript->transcript_status ne 'unknown' and $transcript->source ne 'ccds' )
        {
            push @transcripts_priority_2, $transcript;
        }
    }

    my @transcripts_to_evaluate = ( @transcripts_priority_1 )
    ? @transcripts_priority_1
    : ( @transcripts_priority_2 )
    ? @transcripts_priority_2
    : return;
}

sub _transcript_annotation
{
    my ($self, $transcript, $snp) = @_;

    my $ss_window = $transcript->sub_structure_window;
    my ($main_structure) = $ss_window->scroll( $snp->{position} );
    return unless $main_structure;

    # skip psuedogenes
    return unless $ss_window->cds_exons;

    my $structure_type = $main_structure->structure_type;
    # skip micro rnas
    return if $structure_type eq 'rna';
    
    my $method = '_transcript_annotation_for_' . $structure_type;
    
    my %structure_annotation = $self->$method($transcript, $snp)
        or return;

    my $source = $transcript->source;
    my $gene = $transcript->gene;
    my $expression = $gene->expressions_by_intensity->first;
    my ($intensity, $detection) = ( $expression )
    ? ( $expression->expression_intensity, $expression->detection )
    : (qw/ NULL NULL /);
    
    return 
    (
        %structure_annotation,
        transcript_name => $transcript->transcript_name, 
        transcript_source => $source,
        gene_name  => $gene->name($source),
        intensity => $intensity,
        detection => $detection,
    )
}

sub _transcript_annotation_for_utr_exon
{
    my ($self, $transcript, $snp) = @_;

    my $position = $snp->{position};
    my $strand = $transcript->strand;
    my ($cds_exon_start, $cds_exon_stop) = $transcript->sub_structure_window->cds_exon_range;
    my ($c_position, $trv_type);
    if ( $position < $cds_exon_start )	
    { 
        ($c_position, $trv_type) = ( $transcript->strand eq '+1' )
        ? (($position - $cds_exon_start), "5_prime_untranslated_region")
        : (("*" . ($cds_exon_start - $position)), "3_prime_untranslated_region");
    }
    elsif ( $position > $cds_exon_stop )
    {
        ($c_position, $trv_type) = ( $transcript->strand eq '-1' )
        ? (($cds_exon_stop - $position), "5_prime_untranslated_region")
        : (("*" . ($position - $cds_exon_stop)), "3_prime_untranslated_region"); 
    }
    # TODO else??

    return
    (
        strand => $strand,
        c_position => $c_position,
        trv_type => $trv_type,
        amino_acid_length => length( $transcript->protein->amino_acid_seq ),
    );
}

sub _transcript_annotation_for_flank
{
    my ($self, $transcript, $snp) = @_;

    my $position = $snp->{position};
    my $strand = $transcript->strand;
    my @cds_exon_positions = $transcript->sub_structure_window->cds_exon_range
        or return;
    #   print Dumper([$transcript->transcript_id, $position, $cds_exon_start, $cds_exon_stop]);
    my ($c_position, $trv_type);
    if ( $position < $transcript->transcript_start )
    {	 
        ($c_position, $trv_type) = ( $transcript->strand eq '+1' )
        ? (($position - $cds_exon_positions[0]), "5_prime_flanking_region")
        : (("*" . ($cds_exon_positions[0] - $position)), "3_prime_flanking_region"); 
    }
    elsif ( $position > $transcript->transcript_stop )	
    {
        ($c_position, $trv_type) = ( $transcript->strand eq '-1' )
        ? (($cds_exon_positions[1] - $position), "5_prime_flanking_region")
        : (("*" . ($position - $cds_exon_positions[1])), "3_prime_flanking_region");
    }
    # TODO else??
    
    return
    (
        strand => $strand,
        c_position => $c_position,
        trv_type => $trv_type,
        amino_acid_length => length( $transcript->protein->amino_acid_seq ),
    );
}

sub _transcript_annotation_for_intron 
{
    my ($self, $transcript, $snp) = @_;

    my $strand = $transcript->strand;
    
    my ($cds_exon_start, $cds_exon_stop) = $transcript->sub_structure_window->cds_exon_range;
    my ($oriented_cds_exon_start, $oriented_cds_exon_stop) = ($cds_exon_start, $cds_exon_stop);
    
    my $main_structure = $transcript->sub_structure_window->main_structure;
    my $structure_start = $main_structure->structure_start;
    my $structure_stop = $main_structure->structure_stop;
    my ($oriented_structure_start, $oriented_structure_stop) = ($structure_start, $structure_stop);

    my ($prev_structure, $next_structure) = $transcript->sub_structure_window->structures_flanking_main_structure;
    #return unless $prev_structure and $next_structure;
    my ($prev_structure_type, $next_structure_type, $position_before, $position_after);

    if ( $strand eq '-1' ) 
    {
        # COMPLEMENTED
        ($oriented_structure_stop, $oriented_structure_start) = ($structure_start, $structure_stop);
        ($oriented_cds_exon_stop, $oriented_cds_exon_start) = ($cds_exon_start, $cds_exon_stop);
        ($next_structure_type, $prev_structure_type) = ($prev_structure_type, $next_structure_type);
        $prev_structure_type = $next_structure->structure_type;
        $next_structure_type = $prev_structure->structure_type;
        $position_before = $structure_stop + 1;
        $position_after = $structure_start - 1;
    }	 
    else
    { 
        # UNCOMPLEMENTED
        $prev_structure_type = $prev_structure->structure_type;
        $next_structure_type = $next_structure->structure_type;
        $position_before = $structure_start - 1;
        $position_after = $structure_stop + 1;
    }

    my $exon_pos = $transcript->sub_structure_window->length_of_cds_exons_before_main_structure($strand),
    my $pre_start = abs( $snp->{position} - $oriented_structure_start ) + 1,
    my $pre_end = abs( $snp->{position} - $oriented_structure_start ) + 1,
    my $aft_start = abs( $oriented_structure_stop - $snp->{position} ) + 1,
    my $aft_end = abs( $oriented_structure_stop - $snp->{position} ) + 1,

    my ($c_position, $trv_type);
    if ( $pre_start - 1 <= abs( $structure_stop - $structure_start ) / 2 )
    {
        if ( $prev_structure_type eq "utr_exon" )
        {
            my $diff_start_start = abs( $position_before - $oriented_cds_exon_start );
            my $diff_start_end = abs( $position_before - $oriented_cds_exon_stop );

            if ( abs($diff_start_start) < abs($diff_start_end) )
            {
                $c_position = '-' . $diff_start_start;
            }
            else  
            {
                $c_position = '*' . $diff_start_end;
            }
            $c_position .= '+' . $pre_start; 
        }
        else
        {
            $c_position = $exon_pos . '+' . $pre_start; 
        }
    }
    else
    {
        if ( $next_structure_type eq "utr_exon" ) 
        {
            my $diff_stop_start = abs( $position_after - $oriented_cds_exon_start );
            my $diff_stop_end = abs( $position_after - $oriented_cds_exon_stop );

            if ( abs($diff_stop_start) < abs($diff_stop_end) )
            {
                $c_position = '-' . $diff_stop_start;
            }
            else
            {
                $c_position = '*' . $diff_stop_end;
            }
            $c_position .= '-' . $aft_end;
        }
        else 
        {
            $c_position = ($exon_pos + 1) . '-' . $aft_end;
        }
    }

    if ( $pre_end <= 2 or $aft_start <= 2 ) 
    {
        # intron SS
        $trv_type = "splice_site";
    }
    elsif ( ($pre_start >= 3 and $pre_end <= 10) 
            or ($aft_start <= 10 and $aft_end >= 3) )
    {
        # intron SR
        $trv_type = "splice_region"; 	
    }  
    else
    {
        # intron NN 
        $trv_type = "intronic";
    }	 

    return
    (
        strand => $strand,
        c_position => $c_position,
        trv_type => $trv_type,
        amino_acid_length => length( $transcript->protein->amino_acid_seq ),
    );
}

sub _transcript_annotation_for_cds_exon
{
    my ($self, $transcript, $snp) = @_;
    
    my $strand = $transcript->strand;
    
    my $main_structure = $transcript->sub_structure_window->main_structure;
    my $structure_start = $main_structure->structure_start;
    my $structure_stop = $main_structure->structure_stop;
    my ($oriented_structure_start, $oriented_structure_stop) = ($structure_start, $structure_stop);

    if ( $strand eq '-1' ) 
    {
        # COMPLEMENTED
        ($oriented_structure_stop, $oriented_structure_start) = ($structure_start, $structure_stop);
    }	 

    my $exon_pos = $transcript->sub_structure_window->length_of_cds_exons_before_main_structure($strand);
    my $pre_start = abs( $snp->{position} - $oriented_structure_start ) + 1;
    my $pre_end = abs( $snp->{position} - $oriented_structure_start ) + 1;
    my $aft_start = abs( $oriented_structure_stop - $snp->{position} ) + 1;
    my $aft_end = abs( $oriented_structure_stop - $snp->{position} ) + 1;

    my $trsub_phase = $exon_pos % 3;
    unless ( $trsub_phase eq $main_structure->phase ) 
    {
        $self->error_msg
        (
            sprintf
            (
                'Calculated phase (%d) does not match the phase (%d, exon position: %d) for the main sub structure (%d) for transcript (%d) at %d',
                $trsub_phase,
                $main_structure->phase,
                $exon_pos,
                $main_structure->transcript_structure_id,
                $transcript->transcript_id,
                $snp->{position},
            )
        );
        return;
    }	

    my $c_position = $pre_start + $exon_pos;
    my $codon_start = $c_position % 3;
    my $pro_start = int( $c_position / 3 );
    $pro_start++ if $codon_start != 0; 
    my $amino_acid_seq = $transcript->protein->amino_acid_seq; 
    my $aa_be = substr($amino_acid_seq, $pro_start - 1, 1);
    $aa_be = "*" if $aa_be eq "" or $aa_be eq "X";
    my $amino_acid_change = "p." . $aa_be . $pro_start;

    # get 3 amino acid to codon
    my $chose_ord = ( ($codon_start == 0 and $pre_start <= 2) or ($codon_start == 2 and $pre_start == 1) )
    ? -1 
    : ( ($codon_start == 1 and $aft_start <= 2) or ($codon_start == 2 and $aft_start == 1) )
    ? 1
    : 0;

    my $codonstr;
    if ($chose_ord == 0 )  
    {
        $codonstr = substr($main_structure->nucleotide_seq, $pre_start - 1 - ($codon_start + 2) % 3, 3);
    }
    else
    {
        my $ordinal = $main_structure->ordinal + $chose_ord;
        my $cds_exon = $transcript->sub_structure_window->cds_exon_with_ordinal($ordinal);
        unless ( defined $cds_exon )
        {
            $self->error_msg
            (
                sprintf
                (
                    "Next cds exon (ordinal: %d, next ordinal: %s, chose ordinal: %s) for cds exon (%d) not found after in transcript (%d) at %d",
                    $main_structure->ordinal, 
                    $ordinal,
                    $chose_ord,
                    $main_structure->transcript_structure_id,
                    $transcript->transcript_id,
                    $snp->{position},
                )
            );
            return ;
        }

        if ( $chose_ord == 1 )
        {
            ($main_structure, $cds_exon) = ($cds_exon, $main_structure);
            $trsub_phase = ($exon_pos + $cds_exon->structure_stop - $cds_exon->structure_start + 1) % 3;
        }

        $codonstr = substr
        (
            $cds_exon->nucleotide_seq,
            length( $cds_exon->nucleotide_seq ) - $trsub_phase,
            $trsub_phase
        ) . substr
        (
            $main_structure->nucleotide_seq,
            0,
            3 - $trsub_phase
        );
    }

    my $test_aa_be = $codon2single{ uc $codonstr };
    unless ( ( $test_aa_be eq $aa_be) or ($test_aa_be eq "" and $aa_be eq "*") ) 
    { 
        $self->error_msg
        (
            sprintf
            (
                'Calculated amino acid (%s) does not match the expected amino acid (%s) for the main sub structure (%d) for transcript (%d) in codon string (%s) at %d',
                $aa_be,
                $test_aa_be,
                $main_structure->transcript_structure_id,
                $transcript->transcript_id,
                $codonstr,
                $snp->{position},
            )
        );
        return;
    }		

    my $ref = $snp->{reference}; #was allele1
    my $variant = $snp->{variant}; #was allele2		 
    if ( $strand eq '-1' ) 
    {
        $ref =~tr/ATGC/TACG/;
        $variant =~tr/ATGC/TACG/;
    }	

    my $ref_codon_check = substr($codonstr, $codon_start - 1, 1);
    if ( $ref ne $ref_codon_check )
    {
        $self->error_msg
        (
            sprintf
            (
                "Reference (%s) does not match the base (%s) stored in transcript (%d) at %d",
                $ref,
                $ref_codon_check,
                $transcript->transcript_id,
                $snp->{position},
            )
        );
        return;
    }
    
    substr($codonstr, $codon_start - 1, 1) = $variant;

    my $aa_af = $codon2single{uc $codonstr};
    my $trv_type;
    if ( $aa_af eq 'X' )
    {
        $trv_type = "nonsense";
        $amino_acid_change .= "*";
    }
    elsif ( $aa_be ne $aa_af ) 
    {
        if($aa_be eq '*')  
        {
            $trv_type = "nonstop";
        }
        elsif ( $aa_af eq '*' )
        {
            $trv_type = "nonsense";
        }
        else
        {
            $trv_type = "missense";
        }
        $amino_acid_change .= "$aa_af";
    }
    else 
    {
        $trv_type = "silent"; 
    }

    return 
    (
        strand => $strand,
        c_position => $c_position, 
        trv_type => $trv_type,
        amino_acid_change => $amino_acid_change,
        amino_acid_length => length($amino_acid_seq),
    );
}

sub _variation_sources
{
    my ($self, $snp) = @_;

    my %sources;
    foreach my $variation ( $self->variation_window->scroll( $snp->{position} ) )
    {
        next unless $variation->start eq $variation->end;
        $sources{ $variation->source }++;
    }

    return \%sources;
}

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

