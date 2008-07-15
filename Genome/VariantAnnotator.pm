package Genome::VariantAnnotator;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use Genome::Info::CodonToAminoAcid;
use Genome::Info::VariantPriorities;
use MG::ConsScore;
use List::MoreUtils qw/ uniq /;
use SnpDom;

my %trans_win :name(transcript_window:r) :isa('object');
my %var_win :name(variation_window:r) :isa('object');

my %variant_priorities = Genome::Info::VariantPriorities->for_annotation;
my %codon2single = Genome::Info::CodonToAminoAcid->single_letter;

#- Variations -#
sub variations_for_indel
{
    my ($self, %indel) = @_;

    return $self->variation_window->scroll($indel{start}, $indel{stop});
    ######

    my %sources;
    for my $variation ( $self->variation_window->scroll($indel{start}, $indel{stop}) )
    {
        $sources{ $variation->source }++;
    }

    return \%sources;
}

sub variations_for_snp
{
    my ($self, %snp) = @_;

    return grep { $_->start eq $_->end } $self->variation_window->scroll($snp{start});
    #####

    my %sources;
    for my $variation ( $self->variation_window->scroll($snp{start}) )
    {
        next unless $variation->start eq $variation->end;
        $sources{ $variation->source }++;
    }

    return \%sources;
}

#- Transcripts -#
sub transcripts_for_snp
{
    my ($self, %snp) = @_;

    my @transcripts_to_annotate = $self->_determine_transcripts_to_annotate($snp{start})
        or return;
    
    my @annotations;
    foreach my $transcript ( @transcripts_to_annotate )
    {
        my %annotation = $self->_transcript_annotation($transcript, \%snp)
            or next;
        push @annotations, \%annotation;
    }

    return @annotations;
}

sub prioritized_transcripts_for_snp
{
    my ($self, %snp) = @_;
    
    my @annotations = $self->transcripts_for_snp(%snp)
        or return;

    return $self->_prioritize_annotations(@annotations);
}

sub prioritized_transcripts_for_indel
{
    my ($self, %indel) = @_;
    
    my @annotations = $self->transcripts_for_indel(%indel)
        or return;

    return $self->_prioritize_annotations(@annotations);
}

sub _prioritize_annotations
{
    my ($self, @annotations) = @_;

    my %prioritized_annotations;
    foreach my $annotation ( @annotations )
    {
        # TODO add more priority info in the variat priorities...transcript source, status, etc
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

            if  ( $annotation->{amino_acid_length} == $prioritized_annotations{ $annotation->{gene_name} }->{amino_acid_length} )
            {
                # amino acid length is the same, set the annotation sorted by transcript_name
                ($annotation) = sort 
                {
                    $a->{transcript_name} cmp $b->{transcript_name } 
                } ($annotation, $prioritized_annotations{ $annotation->{gene_name} })
            }
            
            $prioritized_annotations{ $annotation->{gene_name} } = $annotation;
        }
    }
        
    return values %prioritized_annotations;
}

#- Private Methods -#
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
    my ($main_structure) = $ss_window->scroll( $snp->{start} );
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

    my $conservation = $self->_ucsc_cons_annotation($snp);

    return 
    (
        %structure_annotation,
        transcript_name => $transcript->transcript_name, 
        transcript_source => $source,
        gene_name  => $gene->name($source),
        intensity => $intensity,
        detection => $detection,
        amino_acid_change => 'NULL',
        ucsc_cons => $conservation
    )
}

sub _transcript_annotation_for_utr_exon
{
    my ($self, $transcript, $snp) = @_;

    my $position = $snp->{start};
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
        c_position => 'c.' . $c_position,
        trv_type => $trv_type,
        amino_acid_length => length( $transcript->protein->amino_acid_seq ),
        amino_acid_change => 'NULL',
    );
}

sub _transcript_annotation_for_flank
{
    my ($self, $transcript, $snp) = @_;

    my $position = $snp->{start};
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
        c_position => 'c.' . $c_position,
        trv_type => $trv_type,
        amino_acid_length => length( $transcript->protein->amino_acid_seq ),
        amino_acid_change => 'NULL',
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
    my $pre_start = abs( $snp->{start} - $oriented_structure_start ) + 1,
    my $pre_end = abs( $snp->{start} - $oriented_structure_start ) + 1,
    my $aft_start = abs( $oriented_structure_stop - $snp->{start} ) + 1,
    my $aft_end = abs( $oriented_structure_stop - $snp->{start} ) + 1,

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
        c_position => 'c.' . $c_position,
        trv_type => $trv_type,
        amino_acid_length => length( $transcript->protein->amino_acid_seq ),
        amino_acid_change => 'NULL',
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
    my $pre_start = abs( $snp->{start} - $oriented_structure_start ) + 1;
    my $pre_end = abs( $snp->{start} - $oriented_structure_start ) + 1;
    my $aft_start = abs( $oriented_structure_stop - $snp->{start} ) + 1;
    my $aft_end = abs( $oriented_structure_stop - $snp->{start} ) + 1;

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
                $snp->{start},
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
                    $snp->{start},
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
                $snp->{start},
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
                $snp->{start},
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

    my $conservation = $self->_ucsc_cons_annotation($snp);
    my $pdom = $self->_protein_domain($snp,
                                      $transcript->gene,
                                      $transcript->transcript_name,
                                      $amino_acid_change);

    return 
    (
        strand => $strand,
        c_position => 'c.' . $c_position,
        trv_type => $trv_type,
        amino_acid_change => $amino_acid_change,
        amino_acid_length => length($amino_acid_seq),
        ucsc_cons => $conservation,
        domain => $pdom
    );
}

sub _ucsc_cons_annotation
{
    my ($self, $snp) = @_;
    # goto the annotation files for this.
    my $c = new MG::ConsScore(-location => "/gscmnt/temp202/info/medseq/josborne/conservation/b36/fixed-records/");

    my $range = [ $snp->{start}..$snp->{stop} ] ;
    my $ref = $c->get_scores($snp->{chromosome_name},$range);
    my @ret;
    foreach my $item (@$ref)
    {
        push(@ret,sprintf("%.3f",$item->[1]));
    }
    return join(":",@ret); 
}

sub _protein_domain
{
    my ($self, $snp, $gene, $transcript, $amino_acid_change) = @_;
    #
    #my ($gene,$transcript);
    my $s = new SnpDom({'-inc-ts' => 1});
    $s->add_mutation($gene ,$transcript ,$amino_acid_change);
    my %domlen;
    $s->mutation_in_dom(\%domlen,"HMMPfam");
    my $obj = $s->get_mut_obj($transcript . "," . $gene);
    my $doms = $obj->get_domain($amino_acid_change);
    if(defined($doms))
    {
        return join(":", uniq @$doms);
    }
    return 'NULL';
}


1;

=pod

=head1 Name

Genome::SnpAnnotator

=head1 Synopsis

Given information about a 'snp', this modules retrieves annotation information.

=head1 Usage

 my $schema = Genome::DB::Schema->connect_to_dwrac;
 $self->error_message("Can't connect to dwrac")
     and return unless $schema;
    
 my $chromosome_name = $self->chromosome_name;
 my $chromosome = $schema->resultset('Chromosome')->find
 (
     { chromosome_name => $chromosome_name },
 );
 $self->error_message("Can't find chromosome ($chromosome_name)")
     and return unless $chromosome;
 
 my $annotator = Genome::SnpAnnotator->new
 (
     transcript_window => $chromosome->transcript_window(range => $self->flank_range),
     variation_window => $chromosome->variation_window(range => 0),
 );

 while ( my $line = $in_fh->getline )
 {
     my (
         $chromosome_name, $start, $stop, $reference, $variant, 
         $reference_type, $variant_type, $reference_reads, $variant_reads,
         $consensus_quality, $read_count
     ) = split(/\s+/, $line);

     my @annotations = $annotator->get_prioritized_annotations # TODO param whether or not we do prioritized annos?
     (
         position => $start,
         variant => $variant,
         reference => $reference,
     )
         or next;
 
    ...
 }

=head1 Methods

=head2 get_annotations 

=over

=item I<Synopsis>   Gets all annotations for a snp

=item I<Arguments>  snp (hash; see 'SNP' below)

=item I<Returns>    annotations (array of hash refs; see 'Annotation' below)

=back

=head2 get_prioritized_annotations 

=over

=item I<Synopsis>   Gets one prioritized annotation per gene for a snp

=item I<Arguments>  snp (hash; see 'SNP' below)

=item I<Returns>    annotations (array of hash refs; see 'Annotation' below)

=back

=head1 SNP Properties

=over

=item I<position>   The position of the snp

=item I<variant>    The snp base

=item I<reference>  The reference base at the position

=back

=head1 Annotation Properties

=over

=item I<transcript_name>    Name of the transcript

=item I<transcript_source>  Source of the transcript

=item I<strand>             Strand of the transcript

=item I<c_position>         Relative position of the snp

=item I<trv_type>           Type of snp

=item I<priority>           Priority of the trv_type (only from get_prioritized_annotations)

=item I<gene_name>          Gene name of the transcript

=item I<intensity>          Gene intenstiy

=item I<detection>          Gene detection

=item I<amino_acid_length>  Amino acid length of the protein

=item I<amino_acid_change>  Resultant change in amino acid in snp is in cds_exon

=item I<variations>         Hashref w/ keys of known variations at the snp position

=back

=head1 See Also

B<Genome::DB::*>, B<Genome::DB::Window::*>, B<Genome::Model::Command::Report>

=head1 Disclaimer

Copyright (C) 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

B<Xiaoqi Shi> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
