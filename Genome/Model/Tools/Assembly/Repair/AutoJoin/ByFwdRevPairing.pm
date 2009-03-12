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
		 doc => "Length of sequences at each ends to run cross match"        
		 },
	     cm_min_match => {
		 type => 'String',
		 is_optional => 1,
		 doc => "Minimum length of cross match to consider for join"        
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
    if ($self->dir)
    {
	my $dir = $self->dir;
	$self->error_message("Path must be edit_dir") and return
	    unless $dir =~ /edit_dir$/;
	$self->error_message("Invalid dir path: $dir") and return
	    unless -d $dir;
	chdir ("$dir");
    }
    else
    {
	my $dir = cwd();
	$self->error_message("You must be in edit_dir") and return
	    unless $dir =~ /edit_dir$/;
    }

    #ACE FILE
    my $ace_in = $self->ace;

    #CHECK TO MAKE SURE ACE FILE EXISTS
    unless (-s $ace_in)
    {
	$self->error_message("Invalid ace file: $ace_in");
	return;
    }

    #CAT ALL PHDBALL FILES TOGETHER IF PRESENT SINCE PHDBALL FACTORY ONLY
    #WORK WITH SINGLE PHDBALL FILE
    #TODO - FIX THIS IN PHDBALL FACTORY
    unless ($self->cat_all_phdball_files)
    {
	$self->error_message("Cound not resolve phdball issues");
	return;
    }

    #DS LINE IN 454 ACE FILES HAS TO HAVE PHD_FILE: TRACE_NAME TO WORK W CONTIGTOOLS
    #THIS CREATES A NEW ACE FILE: $ace_in.DS_Line_fixed;
    #TODO - FIX THIS IN CONTIG TOOLS
    my $new_ace;
    unless ($new_ace = $self->add_phd_to_ace_DS_line ($ace_in))
    {
	$self->error_message("Cound not add PHD_FILE: READ_NAME to ace DS line");
	return;
    }

    #LOAD ACE OBJECT
    my ($ace_obj, $contig_tool);
    unless (($ace_obj, $contig_tool) = $self->_load_ace_obj ($new_ace))
    {
	$self->error_message("Unable to load ace object");
	return;
    }

    #GET GENERAL CONTIG INFO
    my $scaffolds;
    unless ($scaffolds = $self->get_contigs_info_from_ace ($ace_obj))
    {
	$self->error_message("Could not get contig info from ace");
	return;
    }
#    print Dumper $scaffolds;

    #PRINT CONTIG END SEQUENCES TO RUN CROSS MATCH
    unless ($self->_print_contig_ends ($ace_obj, $scaffolds))
    {
	$self->error_message("Could not print contig ends for cross_match");
	return;
    }

    #RUN CROSS MATCH
    unless ($self->_run_cross_match)
    {
	$self->error_message("Could not run cross_match");
	return;
    }

    #HAVE A GENERIC PARSE CROSS_MATCH METHOD
    my $cross_matches = {};
    unless ($cross_matches = $self->_generic_parse_cross_match())
    {
	$self->error_message("generic parse cross_match failed");
	return;
    }
#    print Dumper $cross_matches;
 
    my $reads_hash;
    unless ($reads_hash = $self->_get_reads($ace_obj))
    {
	$self->error_message("Could not get reads hash");
	return;
    }
#    print Dumper $reads_hash;

    my $end_reads = [];
    unless ($end_reads = $self->_get_contig_end_reads ($reads_hash))
    {
	$self->error_message("Cound not get contig end reads");
	return;
    }
#   print Dumper $end_reads;

    my $paired_end_reads = [];
    unless ( $paired_end_reads = $self->_get_gap_spanning_reads($end_reads, $reads_hash))
    {
	$self->error_message("Could not get paired end reads");
	return;
    }
#    print Dumper $paired_end_reads;

    my $contigs = [];
    unless ($contigs = $self->_orient_contigs ($paired_end_reads))
    {
	$self->error_message("Unable to orient contigs using paired ends");
	return;
    }
#    print Dumper $contigs;

    #THIS IS ONLY NEEDED FOR PRINTING REPORTS??
    my $report;
    unless ($report = $self->_get_report ($contigs))
    {
	$self->error_message("Unable to get report");
	return;
    }
#    print Dumper $report;

    my $potential_joins = [];
    unless ($potential_joins = $self->_find_potential_joins($contigs))
    {
	$self->error_message("find_potential_joins failed");
	return;
    }
#    print Dumper $potential_joins;

    my $joins = {};
    #this should be called something else
    unless ($joins = $self->_align_join_contigs ($potential_joins, $cross_matches))
    {
	$self->error_message("align_join_contigs failed");
	return;
    }

#    print Dumper $joins;

    return 1;
}
sub _generic_parse_cross_match
{
    my ($self) = @_;
    my $reader = Alignment::Crossmatch::Reader->new(io => 'AutoJoin_CM_fasta_out');
    my @alignments = $reader->all;
#    print Dumper \@alignments;
    my $aligns = {};

    foreach (@alignments) {
	#NAMES LOOK LIKE THIS Contig0.1-right
	my $query_name = $_->{query_name};
	my ($query_contig, $query_dir) = $query_name =~ /(\S+)\-(right|left)/;
	my $subject_name = $_->{subject_name};
	my ($subject_contig, $subject_dir) = $subject_name =~ /(\S+)\-(right|left)/;

	#IGNORE INTRA CONTIG HITS;
	next if $query_contig eq $subject_contig;

	#FIGURE OUT IF SUBJECT IS COMPLEMENTED OR NOT
	#IF SUBJECT START IS GREATER THAN SUBJECT STOP, IT'S COMPELMENTED
         	#DOES THIS MATTER??
	#TODO - WHAT HAPPENS IF CONTIG-RIGHT HITS CONTIG-RIGHT

	my $query_start = $_->{query_start};
	my $query_end = $_->{query_stop};
	my $subject_start = $_->{subject_start};
	my $subject_end = $_->{subject_stop};

	my $u_or_c = 'U';
	$u_or_c = 'C' if $subject_start > $subject_end;

	$aligns->{$query_contig}->{$query_dir}->{$subject_contig}->{u_or_c} = $u_or_c;
	$aligns->{$query_contig}->{$query_dir}->{$subject_contig}->{l_or_r} = $subject_dir;
	
    }
    return $aligns;
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

    my $min_match = 25;

    $min_match = $self->cm_min_match if $self->cm_min_match;
    
#   return unless ($self->run_cross_match ($min_match));
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

    my $length = 500;

    $length = $self->cm_fasta_length if $self->cm_fasta_length;

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

	my $size; #estimated insert size #WHY???

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

sub _orient_contigs
{
    my ($self, $l) = @_;
    my $h = {};

    foreach my $line (@$l)
    {
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

sub _get_report
{
    my ($self, $hash) = @_;

    my $report;
    foreach my $ctg (sort keys %$hash) {

	my $line;
	foreach my $dir (sort keys %{$hash->{$ctg}}) {

	    my $direc;
	    #make sure left right is correct
	    $direc = 'left' if $dir eq 'C';
	    $direc = 'right' if $dir eq 'U';
	    $line = "$ctg $direc\n";
	    foreach my $read ( @{ $hash->{$ctg}->{$dir} }) {

		my $mdirec;
		$mdirec = 'left' if $read->{mate_dir} eq 'C';
		$mdirec = 'right' if $read->{mate_dir} eq 'U';
		$line .= "\t".$read->{read}.' => '.$read->{mate_ctg}.' '.$mdirec.' '.
		         $read->{mate}.' '.$read->{ins_size}."\n";
	    }
	    $report .= $line;
	}
    }
    return $report;
}

sub _find_potential_joins
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

#    print Dumper $li;
#    print Dumper $matches;

    my ($hash, $hash2);
    #create a hash to sort joins by numbers of hits
    foreach my $line (@$li) {

	my ($ctg, $dir, $arow, $mdir, $mctg, $rto, $ratio, $spn, $avg, $scr, $score)
	    = split (/\s+/, $line);
	my $info = $mctg.' '.$mdir.' '.$avg.' '.$score.' '.$ratio;

	my ($span_pairs, $all_pairs) = $ratio =~ /(\d+)\/(\d+)/;
	
#	next if $all_pairs < 3;
#	$hash->{$ctg}->{$dir}->{$score}->{info}=$info;

	$hash->{$ctg}->{$dir}->{hit_ratios}->{$score}->{mate_contig}->{name} = $mctg;
	$hash->{$ctg}->{$dir}->{hit_ratios}->{$score}->{mate_contig}->{dir} = $mdir;
	$hash->{$ctg}->{$dir}->{hit_ratios}->{$score}->{mate_contig}->{spanning_pairs} = $span_pairs;
	$hash->{$ctg}->{$dir}->{hit_ratios}->{$score}->{mate_contig}->{total_pairs} = $all_pairs;
    }

#    print Dumper $hash;

    my $join_scaf = {};
    my $contig_dir;
    my $previous_contig;
    my $scaffold;

    foreach my $contig (keys %$hash)
    {
#	print $contig."\n";

	#FIRST CONTIG TO BUILD SCAFFOLD AROUND
	unless ($scaffold) 
	{
	    $scaffold = $contig;
	}

	foreach my $dir (sort keys %{$hash->{$contig}})
	{
#	    print $dir."\n";
	    foreach my $hit_ratio (sort {$b<=>$a} keys %{$hash->{$contig}->{$dir}->{hit_ratios}})
	    {
		#IF HIT RATIO IS GT 80% & THERE'S ENOUGH SPANNING
		#READ PAIRS THEN .CAT THIS CONTIG ONTO 

		if ($hit_ratio ge 0.80)
		{
		    my $next_contig = $hash->{$contig}->{$dir}->{hit_ratios}->{$hit_ratio}->{mate_contig}->{name};
		    if ($dir eq 'left') #NEXT CONTIG MERGED TO THE LEFT
		    {
			
		    }
		    if ($dir eq 'right')
		    {
			
		    }
		    #delete and next;
		}
		#LESS THAN 50 PERCENT .. DON'T JOINS
#		elsif ($hit_ratio le 0.50)
#		{
		    
		    #PREVIOUS CONTIG = CURRENT CONTIGS SO WE CAN GO BACK TO IT
#		}
		#BETWEEN 50 AND 80 PERCENT
#		else
#		{
		    
#		}

		$previous_contig = $contig_dir;
	    }
	} 
    }
    

    

#    foreach my $contig ( sort keys %{$hash} )
#    {
#	foreach my $direct ( sort keys %{$hash->{$contig} } )
#	{
#	    my $sub_list = $contig.'-'.$direct;
#	    my @sub_list;
#	    foreach my $score ( reverse sort keys %{$hash->{$contig}->{$direct} })
#	    {
#		push @{$hash2->{$contig}->{$direct}}, $hash->{$contig}->{$direct}->{$score}->{info};
#	    }
#	}
#    }

#    print Dumper $hash2;
#    return $hash2;

    return 1;
}


1;
