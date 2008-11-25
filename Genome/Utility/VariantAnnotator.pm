package Genome::Utility::VariantAnnotator;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use Genome::Info::CodonToAminoAcid;
use Genome::Info::VariantPriorities;
use MPSampleData::TranscriptSubStructure;
use MG::ConsScore;
use List::MoreUtils qw/ uniq /;
use Benchmark;

my %trans_win :name(transcript_window:r) :isa('object');

my %variant_priorities = Genome::Info::VariantPriorities->for_annotation;
my %codon_to_single = Genome::Info::CodonToAminoAcid->single_letter;

#- Variations -#
#TODO  grep this stuff out of Genome
#removed:
#variations_for_indel, variations_for_snp, var_window accessor
#prioritized_transcripts_for_indel
#prioritized_transcripts_for_snp->prioritized_transcripts
#transcripts_for_snp->transcripts
#return $self->variation_window->scroll($indel{start}, $indel{stop});
#return grep { $_->start eq $_->end } $self->variation_window->scroll($variant{start});


#- Transcripts -#
sub transcripts { # was transcripts_for_snp and transcripts_for_indel
    my ($self, %variant) = @_;

    my @transcripts_to_annotate = $self->_determine_transcripts_to_annotate($variant{start})
        or return;
    
    my @annotations;
    foreach my $transcript ( @transcripts_to_annotate ) {
        my %annotation = $self->_transcript_annotation($transcript, \%variant)
            or next;
        push @annotations, \%annotation;
    }

    return @annotations;
}

sub prioritized_transcripts {# was prioritized_transcripts_for_snp and prioritized_transcripts_for_indel
    my ($self, %variant) = @_;

    my $start = new Benchmark;
    
    my @annotations = $self->transcripts(%variant)
        or return;

    my @prioritized_annotations = $self->_prioritize_annotations(@annotations);

    my $stop = new Benchmark;

    my $time = timestr(timediff($stop, $start));

    print "Annotation Variant: ".$variant{start}."-".$variant{stop}." ".$variant{variant}." ".$variant{reference}." ".$variant{type}." took $time\n";

    return @prioritized_annotations;
}

# Prioritizes annotations on a per gene basis... 
# Currently the "best" annotation is judged by priority, and then source, and then protein length
# in that order.
# I.E. If 6 annotations go in, from 3 different genes, it will select the "best" annotation 
# that each gene has, and return 3 total annotations, one per gene
sub _prioritize_annotations
{
    my ($self, @annotations) = @_;

    my %prioritized_annotations;
    foreach my $annotation ( @annotations )
    {
        # TODO add more priority info in the variant priorities...transcript source, status, etc
        $annotation->{priority} = $variant_priorities{ $annotation->{trv_type} };
        # If no annotation exists for this gene yet, set it
        unless ( exists $prioritized_annotations{ $annotation->{gene_name} } )
        {
            $prioritized_annotations{ $annotation->{gene_name} } = $annotation;
        }
        # If the priority for this new annotation beats the priority for the current best
        # Annotation for this gene, replace the current best with the new best
        elsif ( $annotation->{priority} < $prioritized_annotations{ $annotation->{gene_name} }->{priority} )
        {
            $prioritized_annotations{ $annotation->{gene_name} } = $annotation;
        }
        # If the priorities are a tie, break the tie with source...
        # We currently prefer NCBI annotations over ensembl, and ensembl over other annotations
        elsif ( $annotation->{priority} == $prioritized_annotations{ $annotation->{gene_name} }->{priority} )
        {
            my $new_source_priority = $self->_transcript_source_priority($annotation->{transcript_name});
            my $existing_source_priority = $self->_transcript_source_priority($prioritized_annotations{ $annotation->{gene_name} }->{transcript_name} );
            if ($new_source_priority < $existing_source_priority) {
                $prioritized_annotations{ $annotation->{gene_name} } = $annotation;
            } elsif ($new_source_priority > $existing_source_priority) {
                next;
            # Tied for priority based upon source... break the tie with protein length
            } elsif ($new_source_priority == $existing_source_priority) {
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
    }

    return values %prioritized_annotations;
}

# Takes in a transcript name... uses regex to determine if this
# Transcript is from NCBI, ensembl, etc and returns a priority  number according to which of these we prefer.
# Currently we prefer NCBI to ensembl, and ensembl over others.  Lower priority is preferred
sub _transcript_source_priority {
    my ($self, $transcript) = @_;

    if ($transcript =~ /nm/i) {
        return 1;
    } elsif ($transcript =~ /enst/i) {
        return 2;
    } elsif ($transcript =~ /otthumt/i) {
        return 3;
    }else {
        return 4;
    }
}

#- Private Methods -#
sub _determine_transcripts_to_annotate {
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
    my ($self, $transcript, $variant) = @_;

    #my $ss_window = $transcript->sub_structure_window;
    #my ($main_structure) = $ss_window->scroll( $variant->{start} );
    #return unless $main_structure;

    my $main_structure = $transcript->structure_at_position( $variant->{start} )
        or return;

    # skip psuedogenes
    #return unless $ss_window->cds_exons;
    return unless $transcript->cds_exons;

    my $structure_type = $main_structure->structure_type;
    # skip micro rnas
    return if $structure_type eq 'rna';
    
    my $method = '_transcript_annotation_for_' . $structure_type;
    
    my %structure_annotation = $self->$method($transcript, $variant)
        or return;

    my $source = $transcript->source;
    my $gene = $transcript->gene;
    #my $expression = $gene->expressions_by_intensity->first;
    my @expressions = $gene->expressions_by_intensity;
    my $expression = $expressions[0];
    my ($intensity, $detection) = ( $expression )
    ? ( $expression->expression_intensity, $expression->detection )
    : (qw/ NULL NULL /);

    my $conservation = $self->_ucsc_cons_annotation($variant);
    if(!exists($structure_annotation{domain}))
    {
        $structure_annotation{domain} = 'NULL';
    }

    return (
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
    my ($self, $transcript, $variant) = @_;

    my $position = $variant->{start};
    my $strand = $transcript->strand;
    my ($cds_exon_start, $cds_exon_stop) = $transcript->cds_exon_range;
    #my ($cds_exon_start, $cds_exon_stop) = $transcript->sub_structure_window->cds_exon_range;
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
    my ($self, $transcript, $variant) = @_;

    my $position = $variant->{start};
    my $strand = $transcript->strand;
    my @cds_exon_positions = $transcript->cds_exon_range
    #my @cds_exon_positions = $transcript->sub_structure_window->cds_exon_range
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
# From Chapter 8 codon2aa
#
# A subroutine to translate a DNA 3-character codon to an amino acid
#   Version 3, using hash lookup


}

sub _transcript_annotation_for_intron 
{
    my ($self, $transcript, $variant) = @_;

    my $strand = $transcript->strand;
    
    my ($cds_exon_start, $cds_exon_stop) = $transcript->cds_exon_range;
    #my ($cds_exon_start, $cds_exon_stop) = $transcript->sub_structure_window->cds_exon_range;
    my ($oriented_cds_exon_start, $oriented_cds_exon_stop) = ($cds_exon_start, $cds_exon_stop);
    
    my $main_structure = $transcript->structure_at_position( $variant->{start} );
    #my $main_structure = $transcript->sub_structure_window->main_structure;
# From Chapter 8 codon2aa
#
# A subroutine to translate a DNA 3-character codon to an amino acid
#   Version 3, using hash lookup


    my $structure_start = $main_structure->structure_start;
    my $structure_stop = $main_structure->structure_stop;
    my ($oriented_structure_start, $oriented_structure_stop) = ($structure_start, $structure_stop);

    my ($prev_structure, $next_structure) = $transcript->structures_flanking_structure_at_position( $variant->{start} );
    #my ($prev_structure, $next_structure) = $transcript->sub_structure_window->structures_flanking_main_structure;
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


    my ($c_position, $trv_type);
    #TODO xshi modifications...comes from intron function beginning line 628
    # Should this just check for indel? Probably... since I think this is what is beting passed in right now
    if($variant->{type} =~ /del|ins/i)
    {
        if(($structure_start>=$variant->{start} && $structure_start<=$variant->{stop})||($structure_stop>=$variant->{start} && $structure_stop<=$variant->{stop})||($structure_start<=$variant->{start} && ($structure_start+1)>=$variant->{start})||($structure_stop>=$variant->{stop} && ($structure_stop-1)<=$variant->{stop})) {
            $trv_type="splice_site_". (lc $variant->{type});

        }
        elsif($variant->{start}<=($structure_start+9)||$variant->{stop}>=($structure_stop-9)){
            $trv_type="splice_region_". (lc $variant->{type});
        }
        else {
            $trv_type="intronic";
        }

        return
        (
            strand => $strand,
            c_position => 'c.' . 'NULL',
            trv_type => $trv_type,
            amino_acid_length => length( $transcript->protein->amino_acid_seq ),
            amino_acid_change => 'NULL',
        );
        #TODO  make sure it's okay to return early w/ null c. position
    }
    #end xshi

    my $exon_pos = $transcript->length_of_cds_exons_before_structure_at_position($variant->{start}, $strand);
    my $pre_start = abs( $variant->{start} - $oriented_structure_start ) + 1;
    my $pre_end = abs( $variant->{stop} - $oriented_structure_start ) + 1;
    my $aft_start = abs( $oriented_structure_stop - $variant->{start} ) + 1;
    my $aft_end = abs( $oriented_structure_stop - $variant->{start} ) + 1;

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
# From Chapter 8 codon2aa
#
# A subroutine to translate a DNA 3-character codon to an amino acid
#   Version 3, using hash lookup


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
# From Chapter 8 codon2aa
#
# A subroutine to translate a DNA 3-character codon to an amino acid
#   Version 3, using hash lookup


}

sub _transcript_annotation_for_cds_exon
{
    my ($self, $transcript, $variant) = @_;

    my $strand = $transcript->strand;

    my $main_structure = $transcript->structure_at_position( $variant->{start} );
    #my $main_structure = $transcript->sub_structure_window->main_structure;
    my $structure_start = $main_structure->structure_start;
    my $structure_stop = $main_structure->structure_stop;
    my ($oriented_structure_start, $oriented_structure_stop) = ($structure_start, $structure_stop);

    if ( $strand eq '-1' ) 
    {
        # COMPLEMENTED
# From Chapter 8 codon2aa
#
# A subroutine to translate a DNA 3-character codon to an amino acid
#   Version 3, using hash lookup


        ($oriented_structure_stop, $oriented_structure_start) = ($structure_start, $structure_stop);
    }

    my $exon_pos = $transcript->length_of_cds_exons_before_structure_at_position($variant->{start}, $strand);
    #my $exon_pos = $transcript->sub_structure_window->length_of_cds_exons_before_main_structure($strand);
    my $pre_start = abs( $variant->{start} - $oriented_structure_start ) + 1;
    my $pre_end = abs( $variant->{stop} - $oriented_structure_start ) + 1;
    my $aft_start = abs( $oriented_structure_stop - $variant->{start} ) + 1;
    my $aft_end = abs( $oriented_structure_stop - $variant->{start} ) + 1;

    my $trsub_phase = $exon_pos % 3;
    unless ( $trsub_phase eq $main_structure->phase ) 
    {
        $self->error_msg
        (
# From Chapter 8 codon2aa
#
# A subroutine to translate a DNA 3-character codon to an amino acid
#   Version 3, using hash lookup


            sprintf
            (
                'Calculated phase (%d) does not match the phase (%d, exon position: %d) for the main sub structure (%d) for transcript (%d) at %d',
                $trsub_phase,
                $main_structure->phase,
                $exon_pos,
                $main_structure->transcript_structure_id,
                $transcript->transcript_id,
                $variant->{start},
            )
# From Chapter 8 codon2aa
#
# A subroutine to translate a DNA 3-character codon to an amino acid
#   Version 3, using hash lookup


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

#modifications from xshi...
    my $trv_type;
    my $variant_size=1; 
    my $size1=length($variant->{reference});
    my $size2=length($variant->{variant});

    ($size1,$size2)=($size2,$size1) if ($size1 > $size2);
    my ($reference,$var)=($variant->{reference},$variant->{variant});
    if($strand==-1) {
        $reference=~tr/ATGC/TACG/;
        $var=~tr/ATGC/TACG/;
        $reference=reverse($reference);
        $var=reverse($var);
    }

    my $mutated_seq;
    my $original_seq_translated = $transcript->protein->amino_acid_seq;
    my $mutated_seq_translated;

    my $original_seq=$transcript->cds_full_nucleotide_sequence;

    if($variant->{type} =~ /ins/i) {
        $mutated_seq=substr($original_seq,0,$c_position).$var.substr($original_seq,$c_position);
    }
    elsif($variant->{type} =~ /del/i) {
        $mutated_seq=substr($original_seq,0,$c_position-1).substr($original_seq,$c_position-1+$size2);
    }
    else {
        if(substr($original_seq,$c_position-1,$size2) ne $reference) {
            my $e="allele does not match:" . $transcript->transcript_name.",".$c_position.",".$variant->{chromosome_name}.",".$variant->{start}.",".$variant->{stop}.",".$variant->{reference}.",".$variant->{variant}.",".$variant->{type}."\n";
            $self->error_msg($e);
            return ;
        }
        $variant_size=2 if($codon_start==0);
        $mutated_seq=substr($original_seq,0,$c_position-1).$var.substr($original_seq,$c_position-1+$size2);
    }
    $mutated_seq_translated = $self->translate($mutated_seq);


    my $pro_str;
    if($variant->{type} =~ /del|ins/i) {
        if ($size2%3==0) {$trv_type="in_frame_";}
        else {$trv_type="frame_shift_"; }
        $trv_type.= lc ($variant->{type});
        my $hash_pro= $self->compare_protein_seq($trv_type,$original_seq_translated,$mutated_seq_translated,$pro_start-1,$variant_size);
        $pro_str="p.".$hash_pro->{ori}.$hash_pro->{pos}.$hash_pro->{type}.$hash_pro->{new};
    }
    else {
        if(length($mutated_seq_translated)<$pro_start-1|| substr($original_seq_translated,$pro_start-3,2) ne substr($mutated_seq_translated,$pro_start-3,2)) {
            my $e="protein string does not match:".$transcript->transcript_name.",".$c_position.",".$variant->{chromosome_name}.",".$variant->{start}.",".$variant->{stop}.",".$variant->{reference}.",".$variant->{allele2}.",".$variant->{type}."\n";
            $self->error_msg($e);
            return ;
        }
        my $hash_pro= $self->compare_protein_seq($variant->{type},$original_seq_translated,$mutated_seq_translated,$pro_start-1,$variant_size);
        $trv_type = lc $hash_pro->{type};
        # $anno->{pro_str}="p.".$hash_pro->{ori}.$hash_pro->{pos}.$hash_pro->{new}; #FIXME... so I guess just return this as part of the return hash? pro_str? Is there a paralell?
        $pro_str="p.".$hash_pro->{ori}.$hash_pro->{pos}.$hash_pro->{new};
    }

    # If the variation has a range, set c_position to that range on the transcript_
    if($variant->{start}!=$variant->{stop}) {
        # If on the negative strand, reverse the range order
        if ($strand =~ '-') { 
            $c_position = ($pre_end+$exon_pos) . '_' . $c_position;
        } else { 
            $c_position.='_'.($pre_end+$exon_pos);
        }      
    }
    # TODO end xshi modifications

    my $conservation = $self->_ucsc_cons_annotation($variant);
    my $pdom = $self->_protein_domain($variant,
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
    my ($self, $variant) = @_;
    # goto the annotation files for this.
    my $c = new MG::ConsScore(-location => "/gscmnt/temp202/info/medseq/josborne/conservation/b36/fixed-records/");

    my $range = [ $variant->{start}..$variant->{stop} ] ;
    my $ref = $c->get_scores($variant->{chromosome_name},$range);
    my @ret;
    foreach my $item (@$ref)
    {
        push(@ret,sprintf("%.3f",$item->[1]));
    }
    return join(":",@ret); 
}

sub _protein_domain
{
    my ($self, $variant, $gene, $transcript, $amino_acid_change) = @_;
    #my ($gene,$transcript);
    require SnpDom;
    my $s = SnpDom->new({'-inc-ts' => 1});
    $s->add_mutation($gene->hugo_gene_name ,$transcript ,$amino_acid_change);
    my %domlen;
    $s->mutation_in_dom(\%domlen,"HMMPfam");
    my $obj = $s->get_mut_obj($transcript . "," . $gene->hugo_gene_name);
    my $doms = $obj->get_domain($amino_acid_change);
    if(defined($doms))
    {
        return join(":", uniq @$doms);
    }
    return 'NULL';
}


sub compare_protein_seq   {
    my $self = shift;
    my ($type,$seq_ori,$seq_new,$pro_start,$size)=@_;
    my $hash_pro;
    my $flag=-1;
    $seq_ori =~ s/[X*]//g; 
    $seq_ori.="*";
    my ($pro_ori,$pro_new,$pro_pos)=("","",0);
    if($type=~/dnp|snp/i){
        $pro_pos=$pro_start+1;

        $seq_ori=substr($seq_ori,$pro_start,$size);
        if($pro_start+$size>length($seq_new)) { $seq_new=substr($seq_new,$pro_start);}
        else {$seq_new=substr($seq_new,$pro_start,$size);}

        if($seq_ori eq $seq_new) {
            $type="Silent";
            $pro_ori=$seq_ori;
            $pro_new="";
        }
        else{
            for(my $k=0;$k<$size&&$k<length($seq_new);$k++){

                my $po=substr($seq_ori,$k,1);
                my $pn=substr($seq_new,$k,1);

                if($po ne $pn) { 
                    $pro_ori.=$po;
                    $pro_new.=$pn;
                }
                elsif($pro_ori eq "") {
                    $pro_pos++;
                }

            }
            #$pro_new=~s/(\*).*/$1/g; 
            if($pro_new =~ /\*/) {$type="Nonsense";}
            elsif($pro_ori =~ /\*/) {$type="Nonstop";}
            else {$type="Missense";}
        }

    }
    elsif($type=~/del|ins/i){
        ($seq_ori,$seq_new) = ($seq_new,$seq_ori) if($type=~/del/i);

        $pro_ori=substr($seq_ori,$pro_start);
        $pro_new=substr($seq_new,$pro_start); 

        my ($i,$j);
        for($i=$pro_start;$i<length($seq_ori);$i++){
            last if($pro_ori eq "*");
            next if(substr($seq_ori,$i,1) eq substr($seq_new,$i,1)) ;

            $pro_ori=substr($seq_ori,$i);
            $pro_new=substr($seq_new,$i); 

            for($j=$i;$j<=$i+1;$j++){
                my $pro_ori_cut=substr($seq_ori,$j);;
                $flag=rindex($seq_new,$pro_ori_cut);  
                last if($flag!=-1);

            }

            last if($flag!=-1||$j==$i+2);
        }
        if($flag!=-1 && length($seq_new)-$flag == length($seq_ori)-$j){
            $pro_ori=substr($seq_ori,$i,$j-$i);;
            $pro_new=substr($seq_new,$i,$flag-$i);
        }
        ($pro_ori,$pro_new) = ($pro_new,$pro_ori) if($type =~ /del/i); 
        if($type =~ /Frame_Shift/i) {
            $pro_ori=substr($pro_ori,0,1) ;
            # two kind of output
            $type="fs";
            $pro_new="";
        }
        $type =~ s/Frame_Shift_//g;
        $type =~ s/In_Frame_//g;
        $type = lc($type);
        $pro_pos=$i+1;
    }
    $hash_pro->{ori}=$pro_ori;
    $hash_pro->{new}=$pro_new;
    $hash_pro->{type}=$type;
    $hash_pro->{pos}=$pro_pos;

    return $hash_pro;

}

sub translate
{
    my $self = shift;
    my ($sequence)=@_;
    my $length=length($sequence);
    my $translation;
    my $i;
    for ($i=0; $i<=$length-2; $i+=3 )
    {
        my $codon=substr($sequence, $i, 3);
        $codon =~ s/N/X/g;
        last if(length($codon)!=3);
        my $aa = $codon_to_single{$codon};
        $aa="*" if ($aa eq 'X');
        $translation.=$aa;
        last if ($aa eq '*');
    }
    return $translation;

}

1;

=pod
sub prioritized_transcripts
{
    my ($self, %indel) = @_;
    
    my @annotations = $self->transcripts_for_indel(%indel)
        or return;

    return $self->_prioritize_annotations(@annotations);
}

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

=item I<Synopsis>   Gets one prioritized annotation per gene for a variant(snp or indel)

=item I<Arguments>  variant (hash; see 'Variant properties' below)

=item I<Returns>    annotations (array of hash refs; see 'Annotation' below)

=back

=head1 Variant Properties

=over

=item I<start>      The start position of the variant

=item I<stop>       The stop position of the variant

=item I<variant>    The snp base

=item I<reference>  The reference base at the position

=item I<type>       snp, ins, or del

=back

=head1 Annotation Properties

=over

=item I<transcript_name>    Name of the transcript

=item I<transcript_source>  Source of the transcript

=item I<strand>             Strand of the transcript

=item I<c_position>         Relative position of the variant

=item I<trv_type>           Called Classification of variant

=item I<priority>           Priority of the trv_type (only from get_prioritized_annotations)

=item I<gene_name>          Gene name of the transcript

=item I<intensity>          Gene intenstiy

=item I<detection>          Gene detection

=item I<amino_acid_length>  Amino acid length of the protein

=item I<amino_acid_change>  Resultant change in amino acid in snp is in cds_exon

=item I<variations>         Hashref w/ keys of known variations at the variant position

=item I<type>               snp, ins, or del

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
