package Genome::Model::Tools::Assembly::Repair::AutoJoin::ByFwdRevPairing;

use strict;
use warnings;
use Genome;

use Data::Dumper;
use Cwd;

use Finishing::Assembly::Factory;
use Finishing::Assembly::ContigTools;

use Alignment::Crossmatch::Reader;
use Sort::Naturally;

class Genome::Model::Tools::Assembly::Repair::AutoJoin::ByFwdRevPairing
{
    is => ['Genome::Model::Tools::Assembly::Repair::AutoJoin'],
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
	     ],
};

sub help_brief {
    'Align contigs by fwd/rev pairing then autojoin'
}

sub help_detail {
    return <<"EOS"
	Align contigs by fwd/rev pairing
EOS
}

sub execute {
    my ($self) = @_;

    #RESOLVE PATH TO DATA
    if ($self->dir) {

	my $dir = $self->dir;
	$self->error_message("Path must be edit_dir") and return
	    unless $dir =~ /edit_dir$/;
	$self->error_message("Invalid dir path: $dir") and return
	    unless -d $dir;
	chdir ("$dir");
    }
    else {

	my $dir = cwd();
	$self->error_message("You must be in edit_dir") and return
	    unless $dir =~ /edit_dir$/;
    }

    #ACE FILE
    my $ace_in = $self->ace;

    #CHECK TO MAKE SURE ACE FILE EXISTS
    unless (-s $ace_in) {

	$self->error_message("Invalid ace file: $ace_in");
	return;
    }

    #CAT ALL PHDBALL FILES TOGETHER IF PRESENT SINCE PHDBALL FACTORY ONLY
    #WORK WITH SINGLE PHDBALL FILE
    #TODO - FIX THIS IN PHDBALL FACTORY
    unless ($self->cat_all_phdball_files) {

	$self->error_message("Cound not resolve phdball issues");
	return;
    }

    #DS LINE IN 454 ACE FILES HAS TO HAVE PHD_FILE: TRACE_NAME TO WORK W CONTIGTOOLS
    #THIS CREATES A NEW ACE FILE: $ace_in.DS_Line_fixed;
    #TODO - FIX THIS IN CONTIG TOOLS
    my $new_ace;
    unless ($new_ace = $self->add_phd_to_ace_DS_line ($ace_in)) {

	$self->error_message("Cound not add PHD_FILE: READ_NAME to ace DS line");
	return;
    }

    #LOAD ACE OBJECT
    my ($ace_obj, $contig_tools);
    unless (($ace_obj, $contig_tools) = $self->_load_ace_obj ($new_ace)) {

	$self->error_message("Unable to load ace object");
	return;
    }

    #GET GENERAL CONTIG INFO
    my $scaffolds;
    unless ($scaffolds = $self->get_contigs_info_from_ace ($ace_obj)) {

	$self->error_message("Could not get contig info from ace");
	return;
    }

    #PRINT CONTIG END SEQUENCES TO RUN CROSS MATCH
    unless ($self->_print_contig_ends ($ace_obj, $scaffolds)) {

	$self->error_message("Could not print contig ends for cross_match");
	return;
    }

    #RUN CROSS MATCH
    unless ($self->_run_cross_match) {

	$self->error_message("Could not run cross_match");
	return;
    }

    #HAVE A GENERIC PARSE CROSS_MATCH METHOD
    my $cm_aligns = {};
    unless ($cm_aligns = $self->parse_cross_match_outfile()) {

	$self->error_message("generic parse cross_match failed");
	return;
    }

    my $reads_hash;
    unless ($reads_hash = $self->_get_reads($ace_obj)) {
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
    unless ($new_scaffolds = $self->_get_new_scaffolds ($fr_aligns, $cm_aligns))
    {
	$self->error_message("Get new scaffolds failed");
	return;
    }

    if ($self->report_only)
    {
	$self->status_message("Printing autojoin report");
	unless ($self->print_report ($new_scaffolds)) {
	    $self->error_message("Unable to print report");
	}
	return 1;
    }

    my $joined_ace;
    unless ($joined_ace =$self->_make_joins ($new_scaffolds, $ace_obj, $contig_tools) )
    {
	$self->error_message("Make joined failed");
	return;
    }

    unless ($self->clean_up_merged_ace ($joined_ace))
    {
	$self->error_message("Failed to clean up merged ace");
	return;
    }

    return 1;
}

sub _test_run_cross_match
{
    my ($self, $min_match) = @_;

    my $fasta_file = 'AutoJoin_CM_fasta';

    unless (-s $fasta_file) {
	$self->error_message ("cross_match input fasta is missing");
	return;
    }

    my $cm_out_file = 'AutoJoin_CM_fasta_out';

    unlink $cm_out_file if -s $cm_out_file;

    my $ec = system ("cross_match $fasta_file -minmatch $min_match -masklevel 101 -tags > $cm_out_file");

    if ($ec) {
	$self->error_message("cross_match failed to run");
	return;
    }

    return 1;
}

sub _run_cross_match
{
    my ($self) = @_;

    my $min_match = $self->cm_min_match;
    
    return unless ($self->_test_run_cross_match ($min_match));
    return 1;
}

sub _load_ace_obj
{
    my ($self, $ace) = @_;

    my $tool = Finishing::Assembly::ContigTools->new;

    my $fo = Finishing::Assembly::Factory->connect('ace', $ace);

    return $fo->get_assembly, $tool;
}

sub _print_contig_ends
{
    my ($self, $ao, $scaf_contigs) = @_;

    my $length = $self->cm_fasta_length;

    unless ($self->print_contig_ends ($ao, $scaf_contigs, $length)) {

	$self->error_message("Failed to print contig ends for cross_match");

	return;
    }

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
    my $min_spanning_pairs = 2;
    $min_spanning_pairs = $self->min_read_num if $self->min_read_num;

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

sub _make_joins
{
    my ($self, $scafs, $ace_obj, $ctg_tool) = @_;

    my $dir = cwd();

    print "Please wait: gathering phds and ace file .. this could take up to 10 minutes\n";

    my $ace_out = $self->ace.'.autojoined';

    my $xport = Finishing::Assembly::Ace::Exporter->new( file => $ace_out );

    my @phd_objs;

    my $phd_dir = "$dir/../phd_dir";

    if (-d $phd_dir)
    {
	my $phd_obj = Finishing::Assembly::Phd->new(input_directory => "$phd_dir");

	unless ($phd_obj)
	{
	    $self->error_message("Unable to create phd_dir object");
	    return;
	}

	push @phd_objs, $phd_obj;
    }

    my $phd_ball = "$dir/../phdball_dir/autoJoinPhdBall";

    if (-s $phd_ball)
    {
        my $phd_ball_obj = Finishing::Assembly::Phd::Ball->connect(ball => $phd_ball);

	unless ($phd_ball_obj)
	{
	    $self->error_message("Unable to create phdball object");
	    return;
	}

        push @phd_objs, $phd_ball_obj;
    }

    unless (scalar @phd_objs > 0)
    {
	$self->error_message("No phd objects were loaded");
	return;
    }

    #create a temp hash to keep track of contigs not joined
    my %unused_contig_names;
    foreach ($ace_obj->contigs->all)
    {
        $unused_contig_names{$_->name} = 1;
    }

    my $join_count = 0;
    my $ace_version = 0;
    my $last_merge_failed = 0;

    foreach my $line (@$scafs)
    {
        #new scaf number?
        #scaffold name is really the first contig name

        my ($new_scaf_name) = $line =~ /^New\s+scaffold:\s+(\d+\.\d+)/;
        $new_scaf_name = 'Contig'.$new_scaf_name;

        $line =~ s/^New\s+scaffold:\s+(\d+\.\d+)\s+//; #GET RID OF THIS
        my @ctgs = split (/\s+\<-\d+-\>\s+/, $line);

        my $next_ctg = shift @ctgs;

        #accepts (1.1) or 1.1 and returns the following
        #Contig1.1, yes for (1.1) and
        #Contig1.1, no for 1.1

        my ($left_ctg_name, $left_comp) = $self->_resolve_complementation ($next_ctg);

        my $left_ctg_obj;

	unless ($left_ctg_obj = $ace_obj->get_contig ($left_ctg_name)) {

	    $self->error_message("Unable to get contig object for $left_ctg_name");
	    return;
	}

	if ($left_comp eq 'yes') {

	    unless ($left_ctg_obj->complement) {

		$self->error_message("Unable to complement contig: $left_ctg_name");
		return;
	    }
	}

        while (scalar @ctgs > 0) {

            $next_ctg = shift @ctgs;
            my ($right_ctg_name, $right_comp) = $self->_resolve_complementation ($next_ctg);

	    #NEED TO RE DEFINE LEFT CONTIG NAME HERE

	    my $left_contig_name = $left_ctg_obj->name;
	    print "Trying to merge $left_contig_name to $right_ctg_name\n";

            my $right_ctg_obj;

	    unless ($right_ctg_obj = $ace_obj->get_contig($right_ctg_name)) {

		$self->error_message("Unable to get contig_obj: $right_ctg_name");
		return;
	    }

	    if ($right_comp eq 'yes') {

		unless ($right_ctg_obj->complement) {

		    $self->error_message("Unable to complement contig: $right_ctg_name");
		    return;
		}
	    }

            eval {
                $left_ctg_obj = $ctg_tool->merge($left_ctg_obj, $right_ctg_obj, undef, phd_array => \@phd_objs);
            };

            if ($@) {
		$last_merge_failed = 1;
		#MERGE FAILED SO EXPORT THE LEFT CONTIG
		print " => Merge failed! \n\tExporting $left_contig_name\n";

		#IT LOOKS LIKE THERE ARE PROBLEMS WITH CONTIG OBJECTS
		#WHEN MERGE FAILS .. SO GET A NEW CONTIG OBJECT

		$left_ctg_obj = $ace_obj->get_contig ($left_ctg_name);

		$xport->export_contig(contig => $left_ctg_obj);

		print "Finished exporting ".$left_ctg_obj->name."\n";

		#REMOVE IT FROM LIST OF CONTIGS THAT WILL LATER ALL BE EXPORTED
		delete $unused_contig_names{$left_ctg_name} if
		    exists $unused_contig_names{$left_ctg_name};
		print "The real right contig name".$right_ctg_obj->name."\n";
		#IF RIGHT CONTIG WAS THE LAST CONTIG IN SCAFFOLD JUST EXPORT THAT TOO
		if (scalar @ctgs == 0) {
		    print "\tExporting $right_ctg_name too\n\tIt's the last contig in scaffold\n";

		    $right_ctg_obj = $ace_obj->get_contig ($right_ctg_name);

		    $xport->export_contig(contig => $right_ctg_obj);
		    delete $unused_contig_names{$right_ctg_name} if
			exists $unused_contig_names{$right_ctg_name};
		    next;
		}

		#MAKE THE RIGHT CONTIG OBJECT THE LEFT CONTIG OBJECT
		print "\tMaking $right_ctg_name left contig to continue merging\n";

		$left_ctg_obj = $right_ctg_obj;
		$left_ctg_name = $left_ctg_obj->name;

		#CONTINUE TO MERGE USING RIGHT CONTIG AS THE NEXT LEFT CONTIG
		next;
            }
	    else {
		print " => Successfully merged $left_ctg_name to $right_ctg_name\n";
		$last_merge_failed = 0;
	    }

	    #TODO CREATE LOG FILE THAT LISTS ALL THE JOINS

            foreach ($left_ctg_name, $right_ctg_name) {
                delete $unused_contig_names{$_} if exists $unused_contig_names{$_};
            }
        }

	unless ($last_merge_failed == 1) {

	    $xport->export_contig(contig => $left_ctg_obj, new_name => $left_ctg_name);
	}
    }

    #need to export all the unused contigs
    if (scalar keys %unused_contig_names > 0) {

	print "Exporting unmerged contigs\n";
        foreach (keys %unused_contig_names) {

            my $contig_obj = $ace_obj->get_contig($_);
	    print "\t".$contig_obj->name."\n";
            $xport->export_contig(contig => $contig_obj);
        }
    }

    $xport->close;

    #TURN THIS BACK ON LATER
#   unlink $phd_ball if -s $phd_ball;

    return $ace_out;
}

sub _resolve_complementation
{
    my ($self, $contig_number) = @_;
    return 'Contig'.$contig_number, 'no' unless $contig_number =~ /\(\S+\)/;
    ($contig_number) = $contig_number =~ /\((\S+)\)/;
    return 'Contig'.$contig_number, 'yes';
}




1;
