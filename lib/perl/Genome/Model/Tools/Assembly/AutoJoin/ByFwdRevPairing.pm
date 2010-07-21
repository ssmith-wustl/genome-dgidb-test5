package Genome::Model::Tools::Assembly::AutoJoin::ByFwdRevPairing;

use strict;
use warnings;
use Genome;

use Data::Dumper;
use Cwd;

use Sort::Naturally;

class Genome::Model::Tools::Assembly::AutoJoin::ByFwdRevPairing
{
    is => ['Genome::Model::Tools::Assembly::AutoJoin'],
    has => [ 
	     ace => {
		 type => 'String',
		 is_optional => 0,
		 doc => "input ace file name"        
		 },
	     dir => {
		 type => 'String',
		 is_optional => 1,
		 doc => "path to data if specified otherwise cwd"
		 },
	     min_length => {
		 type => 'String',
		 is_optional => 1,
		 doc => "minimum match length"        
		 }, 
	     max_length => {
		 type => 'String',
		 is_optional => 1,
		 doc => "maximum crossmatch length"        
		 },
	     min_read_num => {
		 type => 'String',
		 is_optional => 1,
		 doc => "minimum number of reads to support joins"        
		 },
	     cm_fasta_length => {
		 type => 'String',
		 is_optional => 1,
		 default => 500,
		 doc => "Length of sequences at each ends to run cross match"        
		 },
	     cm_min_match => {
		 type => 'String',
		 is_optional => 1,
		 default => 25,
		 doc => "Minimum length of cross match to consider for join"        
		 },
	     report_only => {
		 type => 'Boolean',
		 is_optional => 1,
		 default => 0,
		 doc => "Option to print joins the program finds but not make the joins",
	         },
	     min_spanning_pairs => {
		 type => 'String',
		 is_optional => 1,
		 default => 1,
		 doc => "Minimum number of fwd/rev pairing for join",
	         },
	     ],
};

sub help_brief {
    'Align and join contigs by fwd/rev pairing'
}

sub help_detail {
    return <<"EOS"
	Align contigs by fwd/rev pairing
EOS
}

sub execute {
    my ($self) = @_;
    my $orig_dir = cwd();

    #RETURNS CROSS_MATCH ALIGNMENTS, ACE OBJ AND CTG TOOL
    my ($cm_aligns, $ao, $ct, $scafs);
    unless (($cm_aligns, $ao, $ct, $scafs) = $self->create_alignments() ) {
	$self->error_message("Could not create alignments");
	return;
    }

    my $reads_hash;
    unless ($reads_hash = $self->_get_reads($ao)) {
    	$self->error_message("Could not get reads hash");
	return;
    }

    my $end_reads = [];
    unless ($end_reads = $self->_get_contig_end_reads ($reads_hash)) {
	$self->error_message("Cound not get contig end reads");
	return;
    }

    my $paired_end_reads = [];
    unless ( $paired_end_reads = $self->_get_gap_spanning_reads($end_reads, $reads_hash)) {
	$self->error_message("Could not get paired end reads");
	return;
    }

    #THIS ORIENTS CONTIGS BY
    my $fr_aligned_contigs = [];
    unless ($fr_aligned_contigs = $self->_align_contigs_by_spanning_reads ($paired_end_reads)) {
	$self->error_message("Unable to orient contigs using paired ends");
	return;
    }

    my $gap_span_ratios = [];
    unless ($gap_span_ratios = $self->_find_gap_span_ratios($fr_aligned_contigs)) {
	$self->error_message("find gap span ratios failed");
	return;
    }

    my $fr_aligns = {};
    #TODO - THIS SHOULD BE CALLED SOMETHING ELSE
    unless ($fr_aligns = $self->_align_join_contigs ($gap_span_ratios, $cm_aligns)) {
	$self->error_message("align_join_contigs failed");
	return;
    }

    #USE X-MATCH OUTPUT AND F/R PAIRING TO CREATE NEW SCAFFOLDS
    my $new_scaffolds;
    unless ($new_scaffolds = $self->_get_new_scaffolds ($fr_aligns, $cm_aligns)) {
	$self->error_message("Get new scaffolds failed");
	return;
    }

    if ($self->report_only) {
	$self->status_message("Printing autojoin report");
	unless ($self->print_report ($new_scaffolds)) {
	    $self->error_message("Unable to print report");
	}
	return 1;
    }

    my $joined_ace;
    unless ($joined_ace =$self->make_joins ($new_scaffolds, $ao, $ct) ) {
	$self->error_message("Make joined failed");
	return;
    }

    unless ($self->clean_up_merged_ace ($joined_ace)) {
	$self->error_message("Failed to clean up merged ace");
	return;
    }
    chdir ("$orig_dir");
    return 1;
}

sub _get_reads
{
    my ($self, $ace_obj) = @_;

    my $h = {}; #ALL READS HASH

    #TODO WE ONLY HAVE TO CARE ABOUT PAIRED READS
    #ACTUALLY NEED ALL THE READS SINCE WE DON'T KNOW WHERE THE OTHER PAIRED END READ WILL BE

    foreach my $contig ($ace_obj->contigs->all) {

	my $reads = $contig->assembled_reads;
	my $read_count = 0;
	foreach my $read ($reads->all) {

	    $read_count++;
	    my $name = $read->name;

	    next unless $name =~ /\.[bg]\d+$/ or $name =~ /_[left|right]$/;

	    $h->{$name}->{name} = $name;
	    $h->{$name}->{contig} = $contig->name;
	    $h->{$name}->{contig_length} = $contig->length; #NOT NEEDED .. NO SCREENING CTGS OUT
	    $h->{$name}->{contig_read_count} = $read_count; #LIKE WISE
	    $h->{$name}->{read_pos} = $read->start;

	    my $c_or_u = ($read->complemented)? 'C' : 'U';
	    $h->{$name}->{c_or_u} = $c_or_u;
	}
    }

    return $h;
}

sub _get_contig_end_reads
{
    my ($self, $h) = @_;
    
    my @end_reads;

    foreach my $read (keys %$h) {

	#EXCLUDE 3730 OLIGO WALKS
	next if $read =~ /_[tg]\d+\.[bg]\d+$/;
	#EXCLUDE 454 CONSENSUSES
	next if $read =~ /super/;
	#TODO - EXCLUDE 454 DUPLICATE READS
	#TODO - ADD IN ABILITY TO EXCLUDE CERTAIN LIBRARIES??

	#BASICALLY ONLY GETTING READS THAT ARE IN THE END REGIONS WE'RE INTERESTED IN
	#ALSO MAKE SURE READS ARE POINTING INTO THE GAP
#	my $window = 1000;#bp from either end
	    
#	next unless (
#		     $h->{$read}->{read_pos} <= $window and $h->{$read}->{c_or_u} eq 'C' or
#		     $h->{$read}->{read_pos} >= $h->{$read}->{contig_length} - $window and $h->{$read}->{c_or_u} eq 'U'
#		     );

	push @end_reads, $read;
    }
    return \@end_reads;
}

sub _get_gap_spanning_reads
{
    my ($self, $l, $h) = @_;
    
    my @spans;

    foreach my $read (@$l) {
	my $mate = $read;
	$mate =~ s/\.b/\.g/ if $read =~ /\.b\d+/;
	$mate =~ s/\.g/\.b/ if $read =~ /\.g\d+/;

	#SKIP UNLESS PAIRED READ
	next unless $h->{$mate};

	#EXCLUDE INTRA-CONTIG PAIRS
	next if $h->{$read}->{contig} eq $h->{$mate}->{contig};

	my $size;

	$size = $h->{$mate}->{read_pos}
	             if $h->{$mate}->{c_or_u} eq 'C';
	$size = $h->{$mate}->{contig_length} - $h->{$mate}->{read_pos}
	             if $h->{$mate}->{c_or_u} eq 'U' and $h->{$read}->{read_pos} >= 0;
	$size = $h->{$mate}->{contig_length} + $h->{$mate}->{read_pos}
                     if $h->{$mate}->{c_or_u} eq 'U' and $h->{$read}->{read_pos} < 0;

	push @spans, $h->{$read}->{contig}.' '.$h->{$read}->{c_or_u}.' '.$read.' '.
	         $h->{$mate}->{contig}.' '.$h->{$mate}->{c_or_u}.' '.$mate.' '.
		 $size;
    }

    return \@spans;
}

sub _align_contigs_by_spanning_reads
{
    my ($self, $l) = @_;
    my $h = {};

    foreach my $line (@$l) {

	my ($ctg, $dir, $read, $m_ctg, $m_dir, $m_read, $size) = split (' ', $line);
	push @{$h->{$ctg}->{$dir}}, {
	                                 read => $read,
					 mate => $m_read,
					 mate_dir => $m_dir,
					 mate_ctg => $m_ctg,
					 ins_size => $size,
				     };
    }

    return $h;
}

sub _find_gap_span_ratios
{
    my ($self, $hash) = @_;
    my @list;
    
    foreach my $ctg (sort keys %$hash) {

	foreach my $direc (keys %{$hash->{$ctg}} ) {

	    my $cc = 0;
	    my (@ctgs, $dir);;
	    $dir = 'left' if $direc eq 'C';
	    $dir = 'right' if $direc eq 'U';
	    my $span = 0;
	    foreach my $read ( @{ $hash->{$ctg}->{$direc} } ) {

		$span += $read->{ins_size};
		push @ctgs, $read->{'mate_ctg'}.'-'.$read->{'mate_dir'}.'-'.$read->{ins_size};
		$cc++;
	    }
	    my $hsh;
	    foreach my $ctng (@ctgs) {

		my $match = $ctng;
		$match =~ s/-(\d+)//;
		my @ar = grep (/^$match/, @ctgs);
		my $size = 0;
		foreach my $it (@ar) {

		    ($size) = $it =~ /-(\d+)$/;
		    $size += $size;
		}
		my $ct = @ar;
		my $join;
		$hsh->{$match}->{count}=$ct;
		$hsh->{$match}->{span_size}= int($size/$ct);
		$hsh->{$match}->{join}=$join;
	    }

	    foreach my $hit_ctg (keys %$hsh) {

		my $ratio = $hsh->{$hit_ctg}->{count}.'/'.$cc;
		my $score = sprintf "%.2f", $hsh->{$hit_ctg}->{count} / $cc;
		my $avg_span = $hsh->{$hit_ctg}->{span_size};

		$hit_ctg =~ s/-(\w)//;
		my $di;
		$di = 'left' if $1 eq 'C';
		$di = 'right' if $1 eq 'U';

		my $txt =  $ctg.' '.$dir.' => '.$di.' '.$hit_ctg.' ratio '.$ratio.
		           ' avg_span '.$avg_span.' score '.$score;
		push @list, $txt;
	    }
	}
    }
    return \@list; 
}

sub _align_join_contigs
{
    my ($self, $li, $matches) = @_;

    my ($hash, $hash2);

    #CREATE HASH REF TO SORT AND ACCESS MATCHES BY DESCENDING ORDER 
    #OF HIT RATIOS

    foreach my $line (@$li) {

	my ($ctg, $dir, $arow, $mdir, $mctg, $rto, $ratio, $spn, $avg, $scr, $score)
	    = split (/\s+/, $line);
	my $info = $mctg.' '.$mdir.' '.$avg.' '.$score.' '.$ratio;

	my ($span_pairs, $all_pairs) = $ratio =~ /(\d+)\/(\d+)/;
	
	$hash->{$ctg}->{$dir}->{hit_ratios}->{$score}->{mate_contig}->{name} = $mctg;
	$hash->{$ctg}->{$dir}->{hit_ratios}->{$score}->{mate_contig}->{dir} = $mdir;
	$hash->{$ctg}->{$dir}->{hit_ratios}->{$score}->{mate_contig}->{spanning_pairs} = $span_pairs;
	$hash->{$ctg}->{$dir}->{hit_ratios}->{$score}->{mate_contig}->{total_pairs} = $all_pairs;
    }

    #FIND MAJOR HIT CONTIG .. IF NOT ALL F/R PAIRS ARE TO SAME CONTIGS
    #FIND THE ONE CONTIG MOST F/R HITS GO TO

    #TODO - FIND A RIGHT PLACE TO DO THIS LATER
    my $min_spanning_pairs = $self->min_spanning_pairs;

    my $hit_ratio;

    foreach my $contig (keys %$hash) {

	foreach my $dir (sort keys %{$hash->{$contig}}) {

	    #ITERATE THROUGH TO FIND THE OBVIOUS MAJOR CONTIG HITS .. OVER 80%
	    foreach $hit_ratio (sort {$b<=>$a} keys %{$hash->{$contig}->{$dir}->{hit_ratios}}) {

		if ($hit_ratio ge 0.80) {

		    $hash->{$contig}->{$dir}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{is_major_contig} = 'yes';
		    next;
		}
	    }
	    #ITERATE THROUGH THOSE LESS THAN 80 PERCENT HERE MAJOR HIT CONTIGS IS THE TOP HIT
	    #IF ALL THE OTHER HITS ARE MINIMAL
		

	    my $top_ratio; #TO CAPTURE THE TOP RATIO
	    foreach my $hit_ratio (sort {$b<=>$a} keys %{$hash->{$contig}->{$dir}->{hit_ratios}}) {

		next if exists $hash->{$contig}->{$dir}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{is_major_contig} and
		    $hash->{$contig}->{$dir}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{is_major_contig} eq 'yes';

		unless ($top_ratio) {

		    $top_ratio = $hit_ratio;
		    next;
		}

		my $hit_contig_count = scalar (keys %{$hash->{$contig}->{$dir}->{hit_ratios}});
		
		#THIS IS THE SECOND TO THE TOP RATIO IF THIS IS LESS THAN 0.20
		#CONSIDER THE PREVIOUS THE MAJOR MATCH

		if ($hit_ratio le 0.20) {

		    #SET THE TOP AS MAJOR CONTIG
		    $hash->{$contig}->{$dir}->{hit_ratios}->{$top_ratio}->{mate_contig}->{is_major_contig} = 'yes';
		    next;
		}

		#IF HIT RATIO IS GT 80% & THERE'S ENOUGH SPANNING
		#READ PAIRS THEN .CAT THIS CONTIG ONTO

		my $next_contig = $hash->{$contig}->{$dir}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{name};
		my $total_hits = $hash->{$contig}->{$dir}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{total_pairs};
		my $spanning_pairs = $hash->{$contig}->{$dir}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{spanning_pairs};
	    }
	    #DON'T ALLOW CONTIGS WITH LESS THAN MINIMUM SPECIFIED SPANNING READS TO JOIN
	    foreach my $hit_ratio (sort {$b<=>$a} keys %{$hash->{$contig}->{$dir}->{hit_ratios}}) {
		my $spanning_pairs = $hash->{$contig}->{$dir}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{spanning_pairs};

		if ($spanning_pairs <= $min_spanning_pairs) {

		    delete $hash->{$contig}->{$dir}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{is_major_contig} if exists
			$hash->{$contig}->{$dir}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{is_major_contig};

		}
	    }
	} 
    }

    return $hash;
}

#USING X-MATCH ALIGNMENTS AND F/R READ PAIRING
#CREATE NEW SCAFFOLDS
sub _get_new_scaffolds
{
    my ($self, $fr_aligns, $cm_aligns) = @_;

#    OUTPUT SHOULD BE ARYREF LIKE THIS:
#    $VAR1 = [
#          'New scaffold: 0.3 0.3 <-184-> 1.1 <-244-> 1.2 <-43-> (1.3)'
#        ];
    
    my @scaffolds;

    my $last_contig_is_complemented = 0;

    foreach my $contig (keys %$fr_aligns) {

	my ($contig_num) = $contig =~ /contig(\S+)/i;

	my $scaffold = $contig_num;

	my $next_scaf_contig;
	my $scaffold_contig_added = 0;

	foreach my $dir ('left', 'right') {

	    foreach my $hits (keys %{$fr_aligns->{$contig}->{$dir}->{hit_ratios}}) {

		#NEXT UNLESS 
		next unless exists $fr_aligns->{$contig}->{$dir}->{hit_ratios}->{$hits}->{mate_contig}->{is_major_contig} and
		    $fr_aligns->{$contig}->{$dir}->{hit_ratios}->{$hits}->{mate_contig}->{is_major_contig} eq 'yes';
		
		my $join_contig_name = $fr_aligns->{$contig}->{$dir}->{hit_ratios}->{$hits}->{mate_contig}->{name};
		my ($join_contig_num) = $join_contig_name =~ /contig(\S+)/i;
		my $join_contig_dir = $fr_aligns->{$contig}->{$dir}->{hit_ratios}->{$hits}->{mate_contig}->{dir};

		#IF BOTH ARE IN $dir AND $join_contig_dir ARE IN SAME DIRECTION, $join_contig_name
		#MUST BE COMPLEMENTED

		#CHECK TO SEE IF THERE'S A CROSS MATCH MATCH FOR THESE TWO CONTIGS
		if (exists $cm_aligns->{$contig}->{$dir}->{$join_contig_name}) {

		    $scaffold_contig_added++;

		    my $overlap_string = '<-'.$cm_aligns->{$contig}->{$dir}->{$join_contig_name}->{bases_overlap}.'->';

		    my $join_contig_string;
		    #COMPLEMENTED MATCH .. MUST COMPLEMENT JOIN CONTIG
		    if ($dir eq $join_contig_dir) {
			$join_contig_string = '('.$join_contig_num.')';
			$last_contig_is_complemented = 1;
		    }
		    else {
			$join_contig_string = $join_contig_num;
			$last_contig_is_complemented = 0;
		    }

		    if ($dir eq 'left') {
			#CAT STRING TO LEFT
			$scaffold = $join_contig_string.' '.$overlap_string.' '.$scaffold;
		    }
		    else {
			#CAT STRING TO RIGHT
			$scaffold = $scaffold.' '.$overlap_string.' '.$join_contig_string;
		    }

		    #DELETE THE JOINED ENDS
		    delete $fr_aligns->{$contig}->{$dir};
		    delete $fr_aligns->{$join_contig_name}->{$join_contig_dir};

		    #KEEP EXTENDING THE ENDS
		    my $continue = 1;

		    my $next_search_contig_end;
		    my $next_search_contig_name;
		    my $next_join_contig_end;
		    my $next_join_contig_name;

		    while ($continue == 1) {

			unless ($next_search_contig_end) {
			    $next_search_contig_end = $join_contig_dir;
			}
			unless ($next_search_contig_name) {
			    $next_search_contig_name = $join_contig_name;
			}

			$next_search_contig_end = ($next_search_contig_end eq 'left') ? 'right' : 'left';

			if (exists $fr_aligns->{$next_search_contig_name}->{$next_search_contig_end}) {
			    
			    foreach my $hit_ratio (keys %{$fr_aligns->{$next_search_contig_name}->{$next_search_contig_end}->{hit_ratios}}) {

				unless (exists $fr_aligns->{$next_search_contig_name}->{$next_search_contig_end}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{is_major_contig} and
					     $fr_aligns->{$next_search_contig_name}->{$next_search_contig_end}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{is_major_contig} eq 'yes') {
				    $continue = 0;
				    next;
				}
				$next_join_contig_name = $fr_aligns->{$next_search_contig_name}->{$next_search_contig_end}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{name};
				$next_join_contig_end = $fr_aligns->{$next_search_contig_name}->{$next_search_contig_end}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{dir};

				#CHECK CM ALIGNMENTS FOR MATCHING ALIGNMENT
				if (exists $cm_aligns->{$next_search_contig_name}->{$next_search_contig_end}->{$next_join_contig_name}) {
		    
				    my $next_overlap_string = '<-'.$cm_aligns->{$next_search_contig_name}->{$next_search_contig_end}->{$next_join_contig_name}->{bases_overlap}.'->';

				    my ($next_join_contig_num) = $next_join_contig_name =~ /contig(\S+)/i;
				    
				    my $next_join_contig_string;
				    if ($last_contig_is_complemented == 1 and $next_search_contig_end ne $next_join_contig_end) {
					#NO NEED TO COMPLEMENT $next_join_contig_name
					$next_join_contig_string = '('.$next_join_contig_num.')';
					$last_contig_is_complemented = 1;
				    }
				    elsif ($last_contig_is_complemented == 0 and $next_search_contig_end eq $next_join_contig_end) {
					#COMPLEMENT $next_join_contig_name
					$next_join_contig_string = '('.$next_join_contig_num.')';
					$last_contig_is_complemented = 1;
				    }
				    else {
					$next_join_contig_string = $next_join_contig_num;
					$last_contig_is_complemented = 0;
				    }

				    if ($dir eq 'left') {
					$scaffold = $next_join_contig_string.' '.$next_overlap_string.' '.$scaffold;
				    }
				    else {
					$scaffold = $scaffold.' '.$next_overlap_string.' '.$next_join_contig_string;
				    }

				    delete $fr_aligns->{$next_search_contig_name}->{$next_search_contig_end};
				    delete $fr_aligns->{$next_join_contig_name}->{$next_join_contig_end};
				}
			    }
			}
			else {
			    $continue = 0;
			}
			
			$next_search_contig_end = $next_join_contig_end;
			$next_search_contig_name = $next_join_contig_name;
		    }

		}
		else {
		    next;
		}
	    }
	}

	if ($scaffold_contig_added > 0) {
	    push @scaffolds, $scaffold;
	    $scaffold_contig_added = 0;
	}

    }
    
    #THIS SHOULD BE MAKE UNNECESSARY

    my @updated_scaffolds;

    foreach my $scaffold (@scaffolds) {
	my ($new_scaffold_name) = $scaffold =~ /(\S+)\s+/;
	
	$scaffold = 'New scaffold: '.$new_scaffold_name.' '.$scaffold;
	push @updated_scaffolds, $scaffold;
    }

    @scaffolds = undef;

    return \@updated_scaffolds;
}

1;
