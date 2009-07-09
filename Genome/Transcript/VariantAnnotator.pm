package Genome::Transcript::VariantAnnotator;

use strict;
use warnings;

use Data::Dumper;
use Genome::Info::VariantPriorities;
use MG::ConsScore;
use List::MoreUtils qw/ uniq /;
use Benchmark;
use Bio::Tools::CodonTable;

class Genome::Transcript::VariantAnnotator{
    is => 'UR::Object',
    has => [
        transcript_window => {is => 'Genome::Utility::Window::Transcript'},
        benchmark => {
            is => 'boolean',
            is_optional => 1,
        },
        codon_translator => {
            is => 'Bio::Tools::CodonTable',
            is_optional => 1,
        },
        mitochondrial_codon_translator => {
            is => 'Bio::Tools::CodonTable',
            is_optional => 1,
        },
    ]
};

my %variant_priorities = Genome::Info::VariantPriorities->for_annotation;

local $SIG{__WARN__} = sub { 
    __PACKAGE__->save_error_producing_variant(); 
    warn @_ 
};

sub warning_message{
    my $self = shift;
    $self->save_error_producing_variant();
    $self->SUPER::warning_message(@_);
}

sub error_message{
    my $self = shift;
    $self->save_error_producing_variant();
    $self->SUPER::error_message(@_);
}

sub save_error_producing_variant{
    unless ($Genome::Transcript::VariantAnnotator::error_fh){
        $Genome::Transcript::VariantAnnotator::error_fh = IO::File->new(">variant_annotator_error_producing_variants".time.".tsv");
    }
    my $line = join("\t", map {$Genome::Transcript::VariantAnnotator::current_variant->{$_}} (qw/chromosome_name start stop reference variant/));
    if ($Genome::Transcript::VariantAnnotator::last_printed_line){
        unless ($line eq $Genome::Transcript::VariantAnnotator::last_printed_line){
            $Genome::Transcript::VariantAnnotator::error_fh->print($line);
            $Genome::Transcript::VariantAnnotator::last_printed_line = $line;
        }
    }else{
        $Genome::Transcript::VariantAnnotator::error_fh->print($line."\n");
        $Genome::Transcript::VariantAnnotator::last_printed_line = $line;
    }
}

#override create and instantiate codon_translators
sub create{
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    $self->codon_translator( Bio::Tools::CodonTable->new( -id => 1) );
    $self->mitochondrial_codon_translator( Bio::Tools::CodonTable->new( -id => 2) );

    return $self;
}

#- Transcripts -#
sub transcripts { # was transcripts_for_snp and transcripts_for_indel
    my ($self, %variant) = @_;

    $Genome::Transcript::VariantAnnotator::current_variant = \%variant; #for error tracking, we will create a variant file that exposes warnings and errors in the system

    # Make sure variant is set properly
    unless (defined($variant{start}) and defined($variant{stop}) and defined($variant{variant}) and defined($variant{reference}) and defined($variant{type}) and defined($variant{chromosome_name})) {
        print Dumper(\%variant);
        die "Variant is not fully defined... start, stop, variant, reference, and type must be defined.\n";
    }

    my $start = new Benchmark;
    my @transcripts_to_annotate = $self->_determine_transcripts_to_annotate($variant{start})
        or return;

    my @annotations;
    foreach my $transcript ( @transcripts_to_annotate ) {
        unless ($self->is_valid_transcript($transcript)){  #TODO, record this?  eventually remove, as data sanity should be resolved elsewhere
            next;
        }
        my %annotation = $self->_transcript_annotation($transcript, \%variant)
            or next;
        push @annotations, \%annotation;
    }

    my $stop = new Benchmark;

    my $time = timestr(timediff($stop, $start));

    if ($self->benchmark){
        print "Annotation Variant: ".$variant{start}."-".$variant{stop}." ".$variant{variant}." ".$variant{reference}." ".$variant{type}." took $time\n"; 
    }

    return @annotations;
}

sub is_valid_transcript{
    my ($self, $transcript) = @_;
    my $strand = $transcript->strand;
    if ($strand eq '+1' or $strand eq '-1'){
        return 1;
    }else{
        $self->warning_message(sprintf("invalid transcript strand($strand)! id:%d pos: %d %d %d", $transcript->transcript_id, $transcript->chrom_name, $transcript->transcript_start, $transcript->transcript_stop));
        return undef;
    }
}

sub prioritized_transcripts {# was prioritized_transcripts_for_snp and prioritized_transcripts_for_indel
    my ($self, %variant) = @_;


    my @annotations = $self->transcripts(%variant)
        or return;

    my @prioritized_annotations = $self->_prioritize_annotations_per_gene(@annotations);

    return @prioritized_annotations;
}

sub prioritized_transcript{
    my ($self, %variant) = @_;
    my @annotations = $self->transcripts(%variant)
        or return;

    my $annotation = $self->_prioritize_annotations_across_genes(@annotations);

    return $annotation;
}

# Prioritizes annotations on a per gene basis... 
# Currently the "best" annotation is judged by priority, and then source, and then protein length
# in that order.
# I.E. If 6 annotations go in, from 3 different genes, it will select the "best" annotation 
# that each gene has, and return 3 total annotations, one per gene
sub _prioritize_annotations_per_gene
{
    my ($self, @annotations) = @_;

    my %prioritized_annotations;
    foreach my $annotation ( @annotations )
    {
        # TODO add more priority info in the variant priorities...transcript source, status, etc
        $annotation->{priority} = $variant_priorities{ lc($annotation->{trv_type}) };
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


#Takes in prioritized transcripts, returns top annotation among all top gene annotations
sub _prioritize_annotations_across_genes{
    my ($self, @annotations) = @_;
    my $top_annotation;
    for my $annotation (@annotations){
        $annotation->{priority} = $variant_priorities{lc($annotation->{trv_type})};
        if (!$top_annotation){
            $top_annotation = $annotation;
        }elsif ($annotation->{priority} < $top_annotation->{priority}){
            $top_annotation = $annotation;
        }elsif($annotation->{priority} == $top_annotation->{priority}){
            my $new_source_priority = $self->_transcript_source_priority($annotation->{transcript_name});  
            my $current_source_priority = $self->_transcript_source_priority($top_annotation->{transcript_name});  
            if ($new_source_priority < $current_source_priority){
                $top_annotation = $annotation;
            }elsif ($new_source_priority > $current_source_priority){
                next;
            }elsif($new_source_priority == $current_source_priority){
                next if $annotation->{amino_acid_length} < $top_annotation->{amino_acid_length};

                if ( $annotation->{amino_acid_length} == $top_annotation->{amino_acid_length} )
                {
                    ($top_annotation) = sort {$a->{transcript_name} cmp $b->{transcript_name}}($annotation, $top_annotation);
                }else{
                    $top_annotation = $annotation;
                }
            }
        }
    }
    return $top_annotation;
}

# Takes in a transcript name... uses regex to determine if this
# Transcript is from NCBI, ensembl, etc and returns a priority  number according to which of these we prefer.
# Currently we prefer NCBI to ensembl, and ensembl over others.  Lower priority is preferred
sub _transcript_source_priority {
    my ($self, $transcript) = @_;

    if ($transcript =~ /[nx]m/i) {
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

    my @transcripts_priority_1;
    foreach my $transcript ( $self->transcript_window->scroll($position) )
    {
        if ( $transcript->transcript_status ne 'unknown' and $transcript->source ne 'ccds' )
        {
            push @transcripts_priority_1, $transcript;
        }
    }

    return @transcripts_priority_1;
}

sub _transcript_annotation
{
    my ($self, $transcript, $variant) = @_;

    my $main_structure = $transcript->structure_at_position( $variant->{start} )
        or return;
    my $alternate_structure = $transcript->structure_at_position( $variant->{stop} );

    # If alternate sturcture is not defined here we are probably dealing with a very large deletion...
    unless (defined $alternate_structure) {
        $alternate_structure = $main_structure;
        $self->warning_message("Alternate structure is not defined at the stop position (very large deletion? These are not handled well) for variant: " . Dumper $variant);
    }

    my $structure_type = $main_structure->structure_type;
    my $alternate_structure_type = $alternate_structure->structure_type;

    unless ($structure_type eq $alternate_structure_type){
        if ($structure_type eq 'flank'){
            $structure_type = $alternate_structure_type;
        }
        if ($structure_type =~ /intron/){
            $structure_type = $alternate_structure_type if $alternate_structure_type =~ /exon/;
        }
        if ($structure_type eq 'utr_exon'){
            $structure_type = $alternate_structure_type if $alternate_structure_type eq 'cds_exon';
        }
    }

    #print "post: $structure_type : $alternate_structure_type\n";

    my $method = '_transcript_annotation_for_' . $structure_type;

    my %structure_annotation = $self->$method($transcript, $variant)
        or return;

    my $source = $transcript->source;
    my $gene = $transcript->gene;

    my $conservation = $self->_ucsc_cons_annotation($variant);
    if(!exists($structure_annotation{domain}))
    {
        $structure_annotation{domain} = 'NULL';
    }

    return (
        %structure_annotation,
        transcript_name => $transcript->transcript_name, 
        transcript_status => $transcript->transcript_status,
        transcript_source => $source,
        transcript_version => $transcript->build->version,
        gene_name  => $gene->name($source),
#         amino_acid_change => 'NULL',
        ucsc_cons => $conservation
    )
}

sub _transcript_annotation_for_rna
{
    my ($self, $transcript, $variant) = @_;

    my $position = $variant->{start};
    my $strand = $transcript->strand;

    return
    (
        strand => $strand,
        c_position => 'NULL',
        trv_type => 'rna',
        amino_acid_length => 'NULL',  #no protein for rna transcript
        amino_acid_change => 'NULL',
    );
}

sub _transcript_annotation_for_utr_exon
{
    my ($self, $transcript, $variant) = @_;

    my $position = $variant->{start};
    my $strand = $transcript->strand;
    my ($cds_exon_start, $cds_exon_stop) = $transcript->cds_exon_range;
    $cds_exon_start ||= 0;
    $cds_exon_stop ||= 0;
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
        amino_acid_length => 0,
        amino_acid_change => 'NULL',
    );
}

sub _transcript_annotation_for_flank
{
    my ($self, $transcript, $variant) = @_;

    my $position = $variant->{start};
    my $strand = $transcript->strand;

    my @cds_exon_positions = $transcript->cds_exon_range;
    unless (@cds_exon_positions){
        @cds_exon_positions = (0,0);
    }
    my $aas_length=0;
    my $protein = $transcript->protein;
    if ($protein){
        $aas_length = length($protein->amino_acid_seq);
    }
    my ($c_position, $trv_type, $distance_to_transcript);
    if ($transcript->strand eq '+1'){

        if ( $position < $transcript->transcript_start ) {

            $c_position = $position - $cds_exon_positions[0];
            $trv_type = "5_prime_flanking_region";
            $distance_to_transcript =  $position - $transcript->transcript_start;

        }elsif($position > $transcript->transcript_stop){

            $c_position = "*" . ($position - $cds_exon_positions[1]);
            $trv_type = "3_prime_flanking_region";
            $distance_to_transcript =  $position - $transcript->transcript_stop;
        } else {
            $self->warning_message("In _transcript_annotation_for_flank and probably shouldnt be (position falls within the transcript)...");
        }
    }elsif($transcript->strand eq '-1'){

        if ( $position < $transcript->transcript_stop ) {

            $c_position = "*" . ($cds_exon_positions[0] - $position);
            $trv_type = "3_prime_flanking_region";
            $distance_to_transcript = $transcript->transcript_start - $position;

        }elsif($position > $transcript->transcript_start){

            $c_position = $cds_exon_positions[1] - $position;
            $trv_type = "5_prime_flanking_region";
            $distance_to_transcript = $transcript->transcript_stop - $position;
        } else {
            $self->warning_message("In _transcript_annotation_for_flank and probably shouldnt be (position falls within the transcript)...");
        }
    } else {
        $self->warning_message("Invalid strand for transcript: " . $transcript->strand);
    }

    return
    (
        strand => $strand,
        c_position => 'c.' . $c_position,
        trv_type => $trv_type,
        amino_acid_length => $aas_length,
        amino_acid_change => 'NULL',
        flank_annotation_distance_to_transcript => $distance_to_transcript,
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
    $cds_exon_start ||= 0;
    $cds_exon_stop ||= 0;
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
    unless ($prev_structure and $next_structure) {
        $self->warning_message("Previous and/or next structures are undefined for variant (very large deletion? These are not handled well currently), skipping: " . Dumper $variant);
        return;
    }
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



    my $intron_annotation_substructure_size = $structure_stop - $structure_start + 1;
    my @intron_ss = $transcript->introns;
    my $ordinal = 0;
    my $found = 0;
    for my $ordered_intron (@intron_ss){
        $ordinal++;
        #TODO suck it gabe.  This will go away as well after ordinals are properly calculated during anno db import
        if ($ordered_intron->structure_start == $main_structure->structure_start and $ordered_intron->structure_stop == $main_structure->structure_stop){
            $found++; 
            last;
        }
    }
    unless ($found){
        $self->error_message("couldn't calculate intron ordinal position!");
        die;
    }
    my $intron_annotation_substructure_ordinal = $ordinal;
    my $intron_annotation_substructure_position;
    if ($strand eq '-1'){
        $intron_annotation_substructure_position = $structure_stop - $variant->{stop} + 1;
    }else{
        $intron_annotation_substructure_position = $variant->{start} - $structure_start +1;
    }

    my ($c_position, $trv_type);
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
            intron_annotation_substructure_ordinal  => $intron_annotation_substructure_ordinal,
            intron_annotation_substructure_size     => $intron_annotation_substructure_size,
            intron_annotation_substructure_position => $intron_annotation_substructure_position,
        );
        #TODO  make sure it's okay to return early w/ null c. position
    }
    my $utr_pos; 
    my $trsub_start=$main_structure->structure_start-1;
    my $trsub_stop=$main_structure->structure_stop+1;

    return unless((defined $prev_structure && defined $next_structure) && $prev_structure->structure_stop == $trsub_start && $next_structure->structure_start == $trsub_stop); 	 
    if($strand == -1){
        ($cds_exon_start,$cds_exon_stop)=($cds_exon_stop,$cds_exon_start);
        ($trsub_start,$trsub_stop)=($trsub_stop,$trsub_start);
        ($prev_structure,$next_structure)=($next_structure,$prev_structure);
    }
    my $exon_pos = $transcript->length_of_cds_exons_before_structure_at_position($variant->{start}, $strand);

    my $pre_start = abs( $variant->{start} - $oriented_structure_start ) + 1;
    my $pre_end = abs( $variant->{stop} - $oriented_structure_start ) + 1;
    my $aft_start = abs( $oriented_structure_stop - $variant->{start} ) + 1;
    my $aft_end = abs( $oriented_structure_stop - $variant->{start} ) + 1;

    my $diff_stop_start = abs( $position_after - $oriented_cds_exon_start );
    my $diff_stop_end = abs( $position_after - $oriented_cds_exon_stop );
    my $diff_start_start = abs( $position_before - $oriented_cds_exon_start );
    my $diff_start_end = abs( $position_before - $oriented_cds_exon_stop );

    my	$exon_ord=0;
    my	$splice_site_pos;

    if ( $pre_start - 1 <= abs( $structure_stop - $structure_start ) / 2 )
    {
        if ( $prev_structure_type eq "utr_exon" )
        {

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
            $c_position.='_+'.$pre_end if($variant->{start}!=$variant->{stop});
        }
	$exon_ord=$prev_structure->ordinal;
        $splice_site_pos='+'.$pre_start;
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
            $c_position.='_-'.$aft_start if($variant->{start}!=$variant->{stop});
        }
	$exon_ord=$next_structure->ordinal;
        $splice_site_pos='-'.$aft_end;
    }

    my $pro_str = 'NULL';
    if ( $pre_end <= 2 or $aft_start <= 2 ) 
    {
        # intron SS
        $trv_type = "splice_site";
        $pro_str="e".$exon_ord.$splice_site_pos;#
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

    my $protein = $transcript->protein;
    my $aa_seq;
    if ($protein){
        $aa_seq = $protein->amino_acid_seq;
    }else{
        $self->error_message("Couldn't find a protein for transcript ".$transcript->id."! This is bad!");
    }

    return
    (
        strand => $strand,
        c_position => 'c.' . $c_position,
        trv_type => $trv_type,
        amino_acid_length => length( $aa_seq ),
        amino_acid_change => $pro_str,
        intron_annotation_substructure_ordinal  => $intron_annotation_substructure_ordinal,
        intron_annotation_substructure_size     => $intron_annotation_substructure_size,
        intron_annotation_substructure_position => $intron_annotation_substructure_position,
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
        $self->error_message
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
    $c_position-=1 if($strand == -1 && $variant->{type} =~ /ins|del/i );
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
            $self->error_message($e);
            return ;
        }
        $variant_size=2 if($codon_start==0&&$variant->{type}=~/dnp/i);
        $mutated_seq=substr($original_seq,0,$c_position-1).$var.substr($original_seq,$c_position-1+$size2);
    }
    $mutated_seq_translated = $self->translate($variant->{chromosome_name}, $mutated_seq);


    my $pro_str = 'NULL';
    if($variant->{type} =~ /del|ins/i) {
        if ($size2%3==0) {$trv_type="in_frame_";}
        else {$trv_type="frame_shift_"; }
        $trv_type.= lc ($variant->{type});
        my $hash_pro= $self->compare_protein_seq($trv_type,$original_seq_translated,$mutated_seq_translated,$pro_start-1,$variant_size);
        $pro_str="p.".$hash_pro->{ori}.$hash_pro->{pos}.$hash_pro->{type}.$hash_pro->{new};
    }
    else {
        if(length($mutated_seq_translated)<$pro_start-1|| substr($original_seq_translated,$pro_start-3,2) ne substr($mutated_seq_translated,$pro_start-3,2)) {
            my $e="protein string does not match:".$transcript->transcript_name.",".$c_position.",".$variant->{chromosome_name}.",".$variant->{start}.",".$variant->{stop}.",".$variant->{reference}.",".$variant->{variant}.",".$variant->{type}."\n";
            $self->error_message($e);
            return ;
        }
        my $hash_pro= $self->compare_protein_seq($variant->{type},$original_seq_translated,$mutated_seq_translated,$pro_start-1,$variant_size);
        $trv_type = lc $hash_pro->{type};
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
        amino_acid_change => $pro_str,
        amino_acid_length => length($amino_acid_seq),
        ucsc_cons => $conservation,
        domain => $pdom
    );
}

sub _ucsc_cons_annotation
{
    my ($self, $variant) = @_;
    # goto the annotation files for this.
    #print Dumper $variant;
    return 'null' if $variant->{chromosome_name} =~ /^[MN]T/;
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
    $s->add_mutation($gene->name ,$transcript ,$amino_acid_change);
    my %domlen;
    $s->mutation_in_dom(\%domlen,"HMMPfam");
    my $obj = $s->get_mut_obj($transcript . "," . $gene->name);
    return 'NULL' unless $obj;
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
    my ($chrom, $sequence)=@_;
    my $length=length($sequence);
    my $translator = $self->codon_translator;
    if ($chrom =~ /^MT/){
        $translator = $self->mitochondrial_codon_translator;
    }
    my $translation;
    my $i;
    for ($i=0; $i<=$length-2; $i+=3 )
    {
        my $codon=substr($sequence, $i, 3);
        $codon =~ s/N/X/g;
        my $aa = $translator->translate($codon);
        $aa="*" if ($aa eq 'X');
        $translation.=$aa;
        last if ($aa eq '*');
    }
    return $translation;

}

1;

=pod
=head1 Name

Genome::SnpAnnotator

=head1 Synopsis

Given information about a 'snp', this modules retrieves annotation information.

=head1 Usage

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

    my @annotations = $annotator->get_prioritized_annotations
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

B<Genome::Model::Command::Report>

=head1 Disclaimer

Copyright (C) 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

Core Logic:

B<Xiaoqi Shi> I<xshi@genome.wustl.edu>

Optimization:

B<Eddie Belter> I<ebelter@watson.wustl.edu>

B<Gabe Sanderson> l<gsanders@genome.wustl.edu>

B<Adam Dukes l<adukes@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
