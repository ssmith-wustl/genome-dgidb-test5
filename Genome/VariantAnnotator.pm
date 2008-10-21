package Genome::VariantAnnotator;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use Genome::Info::CodonToAminoAcid;
use Genome::Info::VariantPriorities;
use MPSampleData::TranscriptSubStructure;
use MG::ConsScore;
use List::MoreUtils qw/ uniq /;

my %trans_win :name(transcript_window:r) :isa('object');
my %var_win :name(variation_window:r) :isa('object');

my %variant_priorities = Genome::Info::VariantPriorities->for_annotation;
my %codon_to_single = Genome::Info::CodonToAminoAcid->single_letter;

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
    my ($self, $transcript, $snp) = @_;

    #my $ss_window = $transcript->sub_structure_window;
    #my ($main_structure) = $ss_window->scroll( $snp->{start} );
    #return unless $main_structure;

    my $main_structure = $transcript->structure_at_position( $snp->{start} )
        or return;

    # skip psuedogenes
    #return unless $ss_window->cds_exons;
    return unless $transcript->cds_exons;

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
    my ($self, $transcript, $snp) = @_;

    my $position = $snp->{start};
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
    my ($self, $transcript, $snp) = @_;

    my $position = $snp->{start};
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
}

sub _transcript_annotation_for_intron 
{
    my ($self, $transcript, $snp) = @_;

    my $strand = $transcript->strand;
    
    my ($cds_exon_start, $cds_exon_stop) = $transcript->cds_exon_range;
    #my ($cds_exon_start, $cds_exon_stop) = $transcript->sub_structure_window->cds_exon_range;
    my ($oriented_cds_exon_start, $oriented_cds_exon_stop) = ($cds_exon_start, $cds_exon_stop);
    
    my $main_structure = $transcript->structure_at_position( $snp->{start} );
    #my $main_structure = $transcript->sub_structure_window->main_structure;
    my $structure_start = $main_structure->structure_start;
    my $structure_stop = $main_structure->structure_stop;
    my ($oriented_structure_start, $oriented_structure_stop) = ($structure_start, $structure_stop);

    my ($prev_structure, $next_structure) = $transcript->structures_flanking_structure_at_position( $snp->{start} );
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
    if($snp->{type} =~ /del|ins/i)
    {
        if(($structure_start>=$snp->{start} && $structure_start<=$snp->{stop})||($structure_stop>=$snp->{start} && $structure_stop<=$snp->{stop})||($structure_start<=$snp->{start} && ($structure_start+1)>=$snp->{start})||($structure_stop>=$snp->{stop} && ($structure_stop-1)<=$snp->{stop})) {
            $trv_type="splice_site_". (lc $snp->{type});

        }
        elsif($snp->{start}<=($structure_start+9)||$snp->{stop}>=($structure_stop-9)){
            $trv_type="splice_region_". (lc $snp->{type});
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

    my $exon_pos = $transcript->length_of_cds_exons_before_structure_at_position($snp->{start}, $strand);
    my $pre_start = abs( $snp->{start} - $oriented_structure_start ) + 1;
    my $pre_end = abs( $snp->{stop} - $oriented_structure_start ) + 1;
    my $aft_start = abs( $oriented_structure_stop - $snp->{start} ) + 1;
    my $aft_end = abs( $oriented_structure_stop - $snp->{start} ) + 1;

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

    my $main_structure = $transcript->structure_at_position( $snp->{start} );
    #my $main_structure = $transcript->sub_structure_window->main_structure;
    my $structure_start = $main_structure->structure_start;
    my $structure_stop = $main_structure->structure_stop;
    my ($oriented_structure_start, $oriented_structure_stop) = ($structure_start, $structure_stop);

    if ( $strand eq '-1' ) 
    {
        # COMPLEMENTED
        ($oriented_structure_stop, $oriented_structure_start) = ($structure_start, $structure_stop);
    }

    my $exon_pos = $transcript->length_of_cds_exons_before_structure_at_position($snp->{start}, $strand);
    #my $exon_pos = $transcript->sub_structure_window->length_of_cds_exons_before_main_structure($strand);
    my $pre_start = abs( $snp->{start} - $oriented_structure_start ) + 1;
    my $pre_end = abs( $snp->{stop} - $oriented_structure_start ) + 1;
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

#modifications from xshi...
    my $trv_type;
    my $snp_size=1; 
    my $size1=length($snp->{reference});
    my $size2=length($snp->{variant});

    ($size1,$size2)=($size2,$size1) if ($size1 > $size2);
    my ($reference,$variant)=($snp->{reference},$snp->{variant});
    if($strand==-1) {
        $reference=~tr/ATGC/TACG/;
        $variant=~tr/ATGC/TACG/;
        $reference=reverse($reference);
        $variant=reverse($variant);
    }

    my $original_seq="";
    my $mutated_seq;
    my $original_seq_translated = $transcript->protein->amino_acid_seq;
    my $mutated_seq_translated;

    my ($max_ordinal)= $self->get_max_ord($transcript->transcript_id);
    for(my $o=1;$o<=$max_ordinal;$o++)
    {
        $original_seq.= $self->get_exon_seqs($transcript->transcript_id,$o);
    }

    if($snp->{type} =~ /ins/i) {
        $mutated_seq=substr($original_seq,0,$c_position).$variant.substr($original_seq,$c_position);
    }
    elsif($snp->{type} =~ /del/i) {
        $mutated_seq=substr($original_seq,0,$c_position-1).substr($original_seq,$c_position-1+$size2);
    }
    else {
        if(substr($original_seq,$c_position-1,$size2) ne $reference) {
            my $e="allele does not match:" . $transcript->transcript_name.",".$c_position.",".$snp->{chromosome_name}.",".$snp->{start}.",".$snp->{stop}.",".$snp->{reference}.",".$snp->{variant}.",".$snp->{type}."\n";
            $self->error_msg($e);
            return ;
        }
        $snp_size=2 if($codon_start==0);
        #$snp_size=2 if($codon_start==0&&$self->{type}=~/dnp/i); #TODO, add this type check
        $mutated_seq=substr($original_seq,0,$c_position-1).$variant.substr($original_seq,$c_position-1+$size2);
    }
    $mutated_seq_translated = $self->translate($mutated_seq);


    my $pro_str;
    if($snp->{type} =~ /del|ins/i) {
        if ($size2%3==0) {$trv_type="in_frame_";}
        else {$trv_type="frame_shift_"; }
        $trv_type.= lc ($snp->{type});
        my $hash_pro= $self->compare_protein_seq($trv_type,$original_seq_translated,$mutated_seq_translated,$pro_start-1,$snp_size);
        $pro_str="p.".$hash_pro->{ori}.$hash_pro->{pos}.$hash_pro->{type}.$hash_pro->{new};
    }
    else {
        if(length($mutated_seq_translated)<$pro_start-1|| substr($original_seq_translated,$pro_start-3,2) ne substr($mutated_seq_translated,$pro_start-3,2)) {
            my $e="protein string does not match:".$transcript->transcript_name.",".$c_position.",".$snp->{chromosome_name}.",".$snp->{start}.",".$snp->{stop}.",".$snp->{reference}.",".$snp->{allele2}.",".$snp->{type}."\n";
            $self->error_msg($e);
            return ;
        }
        my $hash_pro= $self->compare_protein_seq($snp->{type},$original_seq_translated,$mutated_seq_translated,$pro_start-1,$snp_size);
        $trv_type = lc $hash_pro->{type};
        # $anno->{pro_str}="p.".$hash_pro->{ori}.$hash_pro->{pos}.$hash_pro->{new}; #FIXME... so I guess just return this as part of the return hash? pro_str? Is there a paralell?
        $pro_str="p.".$hash_pro->{ori}.$hash_pro->{pos}.$hash_pro->{new};
    }

    # If the variation has a range, set c_position to that range on the transcript_
    if($snp->{start}!=$snp->{stop}) {
        # If on the negative strand, reverse the range order
        if ($strand =~ '-') { 
            $c_position = ($pre_end+$exon_pos) . '_' . $c_position;
        } else { 
            $c_position.='_'.($pre_end+$exon_pos);
        }      
    }
    # TODO end xshi modifications

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
    #my ($gene,$transcript);
    require SnpDom;
    my $s = SnpDom->new({'-inc-ts' => 1});
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

sub get_max_ord
{
    my $self = shift;
    my ($tr_id)=@_;
    my $sort="DESC";
    my $type="cds_exon";
    my $ord="ordinal";
    my ($max)=MPSampleData::TranscriptSubStructure->retrieve_from_sql
    (
        sprintf
        (
            "transcript_id = ? AND structure_type = ? order by %s %s",
            $ord,
            $sort,
        ),
        $tr_id,
        $type,

    );

    return $max->$ord if ($max);
    return 0;
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

sub get_exon_seqs
{
    my $self = shift;
    my ($tr_id,$ordinal)=@_;
    my $type="cds_exon";
    my ($sth)=MPSampleData::TranscriptSubStructure->retrieve_from_sql
    (
        "transcript_id = ? AND structure_type = ?  AND ordinal = ?",
        $tr_id,
        $type,
        $ordinal,
    );

    return $sth->nucleotide_seq if ($sth);
    return 0;
}


# From Chapter 8 codon2aa
#
# A subroutine to translate a DNA 3-character codon to an amino acid
#   Version 3, using hash lookup

sub TranslationCodon1LetterAA {
    my $self = shift;
    my($codon) = @_;

    $codon = uc $codon;

    my(%genetic_code) = (

        'TCA' => 'S',    # Serine
        'TCC' => 'S',    # Serine
        'TCG' => 'S',    # Serine
        'TCT' => 'S',    # Serine
        'TTC' => 'F',    # Phenylalanine
        'TTT' => 'F',    # Phenylalanine
        'TTA' => 'L',    # Leucine
        'TTG' => 'L',    # Leucine
        'TAC' => 'Y',    # Tyrosine
        'TAT' => 'Y',    # Tyrosine
        'TAA' => 'X',    # Stop
        'TAG' => 'X',    # Stop
        'TGC' => 'C',    # Cysteine
        'TGT' => 'C',    # Cysteine
        'TGA' => 'X',    # Stop
        'TGG' => 'W',    # Tryptophan
        'CTA' => 'L',    # Leucine
        'CTC' => 'L',    # Leucine
        'CTG' => 'L',    # Leucine
        'CTT' => 'L',    # Leucine
        'CCA' => 'P',    # Proline
        'CCC' => 'P',    # Proline
        'CCG' => 'P',    # Proline
        'CCT' => 'P',    # Proline
        'CAC' => 'H',    # Histidine
        'CAT' => 'H',    # Histidine
        'CAA' => 'Q',    # Glutamine
        'CAG' => 'Q',    # Glutamine
        'CGA' => 'R',    # Arginine
        'CGC' => 'R',    # Arginine
        'CGG' => 'R',    # Arginine
        'CGT' => 'R',    # Arginine
        'ATA' => 'I',    # Isoleucine
        'ATC' => 'I',    # Isoleucine
        'ATT' => 'I',    # Isoleucine
        'ATG' => 'M',    # Methionine
        'ACA' => 'T',    # Threonine
        'ACC' => 'T',    # Threonine
        'ACG' => 'T',    # Threonine
        'ACT' => 'T',    # Threonine
        'AAC' => 'N',    # Asparagine
        'AAT' => 'N',    # Asparagine
        'AAA' => 'K',    # Lysine
        'AAG' => 'K',    # Lysine
        'AGC' => 'S',    # Serine
        'AGT' => 'S',    # Serine
        'AGA' => 'R',    # Arginine
        'AGG' => 'R',    # Arginine
        'GTA' => 'V',    # Valine
        'GTC' => 'V',    # Valine
        'GTG' => 'V',    # Valine
        'GTT' => 'V',    # Valine
        'GCA' => 'A',    # Alanine
        'GCC' => 'A',    # Alanine
        'GCG' => 'A',    # Alanine
        'GCT' => 'A',    # Alanine
        'GAC' => 'D',    # Aspartic Acid
        'GAT' => 'D',    # Aspartic Acid
        'GAA' => 'E',    # Glutamic Acid
        'GAG' => 'E',    # Glutamic Acid
        'GGA' => 'G',    # Glycine
        'GGC' => 'G',    # Glycine
        'GGG' => 'G',    # Glycine
        'GGT' => 'G',    # Glycine
        '-TA' => 'indel', #Indel
        '-TC' => 'indel', #Indel
        '-TG' => 'indel', #Indel
        '-TT' => 'indel', #Indel
        '-CA' => 'indel', #Indel
        '-CC' => 'indel', #Indel
        '-CG' => 'indel', #Indel
        '-CT' => 'indel', #Indel
        '-AC' => 'indel', #Indel
        '-AT' => 'indel', #Indel
        '-AA' => 'indel', #Indel
        '-AG' => 'indel', #Indel
        '-GA' => 'indel', #Indel
        '-GC' => 'indel', #Indel
        '-GG' => 'indel', #Indel
        '-GT' => 'indel', #Indel
        'T-A' => 'indel', #Indel
        'T-C' => 'indel', #Indel
        'T-G' => 'indel', #Indel
        'T-T' => 'indel', #Indel
        'C-A' => 'indel', #Indel
        'C-C' => 'indel', #Indel
        'C-G' => 'indel', #Indel
        'C-T' => 'indel', #Indel
        'A-C' => 'indel', #Indel
        'A-T' => 'indel', #Indel
        'A-A' => 'indel', #Indel
        'A-G' => 'indel', #Indel
        'G-A' => 'indel', #Indel
        'G-C' => 'indel', #Indel
        'G-G' => 'indel', #Indel
        'G-T' => 'indel', #Indel
        'TA-' => 'indel', #Indel
        'TC-' => 'indel', #Indel
        'TG-' => 'indel', #Indel
        'TT-' => 'indel', #Indel
        'CA-' => 'indel', #Indel
        'CC-' => 'indel', #Indel
        'CG-' => 'indel', #Indel
        'CT-' => 'indel', #Indel
        'AC-' => 'indel', #Indel
        'AT-' => 'indel', #Indel
        'AA-' => 'indel', #Indel
        'AG-' => 'indel', #Indel
        'GA-' => 'indel', #Indel
        'GC-' => 'indel', #Indel
        'GG-' => 'indel', #Indel
        'GT-' => 'indel', #Indel
        '+TA' => 'refseq allele', #No Indel
        '+TC' => 'refseq allele', #No Indel
        '+TG' => 'refseq allele', #No Indel
        '+TT' => 'refseq allele', #No Indel
        '+CA' => 'refseq allele', #No Indel
        '+CC' => 'refseq allele', #No Indel
        '+CG' => 'refseq allele', #No Indel
        '+CT' => 'refseq allele', #No Indel
        '+AC' => 'refseq allele', #No Indel
        '+AT' => 'refseq allele', #No Indel
        '+AA' => 'refseq allele', #No Indel
        '+AG' => 'refseq allele', #No Indel
        '+GA' => 'refseq allele', #No Indel
        '+GC' => 'refseq allele', #No Indel
        '+GG' => 'refseq allele', #No Indel
        '+GT' => 'refseq allele', #No Indel
        'T+A' => 'refseq allele', #No Indel
        'T+C' => 'refseq allele', #No Indel
        'T+G' => 'refseq allele', #No Indel
        'T+T' => 'refseq allele', #No Indel
        'C+A' => 'refseq allele', #No Indel
        'C+C' => 'refseq allele', #No Indel
        'C+G' => 'refseq allele', #No Indel
        'C+T' => 'refseq allele', #No Indel
        'A+C' => 'refseq allele', #No Indel
        'A+T' => 'refseq allele', #No Indel
        'A+A' => 'refseq allele', #No Indel
        'A+G' => 'refseq allele', #No Indel
        'G+A' => 'refseq allele', #No Indel
        'G+C' => 'refseq allele', #No Indel
        'G+G' => 'refseq allele', #No Indel
        'G+T' => 'refseq allele', #No Indel
        'TA+' => 'refseq allele', #No Indel
        'TC+' => 'refseq allele', #No Indel
        'TG+' => 'refseq allele', #No Indel
        'TT+' => 'refseq allele', #No Indel
        'CA+' => 'refseq allele', #No Indel
        'CC+' => 'refseq allele', #No Indel
        'CG+' => 'refseq allele', #No Indel
        'CT+' => 'refseq allele', #No Indel
        'AC+' => 'refseq allele', #No Indel
        'AT+' => 'refseq allele', #No Indel
        'AA+' => 'refseq allele', #No Indel
        'AG+' => 'refseq allele', #No Indel
        'GA+' => 'refseq allele', #No Indel
        'GC+' => 'refseq allele', #No Indel
        'GG+' => 'refseq allele', #No Indel
        'GT+' => 'refseq allele', #No Indel
        'XTA' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XTC' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XTG' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XTT' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XCA' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XCC' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XCG' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XCT' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XAC' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XAT' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XAA' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XAG' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XGA' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XGC' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XGG' => 'Z', #Discrepant Genotypes in Overlapping Data
        'XGT' => 'Z', #Discrepant Genotypes in Overlapping Data
        'TXA' => 'Z', #Discrepant Genotypes in Overlapping Data
        'TXC' => 'Z', #Discrepant Genotypes in Overlapping Data
        'TXG' => 'Z', #Discrepant Genotypes in Overlapping Data
        'TXT' => 'Z', #Discrepant Genotypes in Overlapping Data
        'CXA' => 'Z', #Discrepant Genotypes in Overlapping Data
        'CXC' => 'Z', #Discrepant Genotypes in Overlapping Data
        'CXG' => 'Z', #Discrepant Genotypes in Overlapping Data
        'CXT' => 'Z', #Discrepant Genotypes in Overlapping Data
        'AXC' => 'Z', #Discrepant Genotypes in Overlapping Data
        'AXT' => 'Z', #Discrepant Genotypes in Overlapping Data
        'AXA' => 'Z', #Discrepant Genotypes in Overlapping Data
        'AXG' => 'Z', #Discrepant Genotypes in Overlapping Data
        'GXA' => 'Z', #Discrepant Genotypes in Overlapping Data
        'GXC' => 'Z', #Discrepant Genotypes in Overlapping Data
        'GXG' => 'Z', #Discrepant Genotypes in Overlapping Data
        'GXT' => 'Z', #Discrepant Genotypes in Overlapping Data
        'TAX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'TCX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'TGX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'TTX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'CAX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'CCX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'CGX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'CTX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'ACX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'ATX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'AAX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'AGX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'GAX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'GCX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'GGX' => 'Z', #Discrepant Genotypes in Overlapping Data
        'GTX' => 'Z', #Discrepant Genotypes in Overlapping Data
    );

    if(exists $genetic_code{$codon}) {
        return $genetic_code{$codon};
    }else{

        print STDERR "Undefined codon \"$codon\" returned U!!\n";
        #exit;
        return "U";

    }
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
