
package Genome::Model::Tools::Newbler::RunStats;

use warnings;
use strict;

use Genome;
use IO::File;
use Bio::SeqIO;
use Bio::Seq::Quality;
use Bio::Seq::SequenceTrace;
use Cwd;

class Genome::Model::Tools::Newbler::RunStats {
    is => 'Command',
    has => [
	    dir => {
		         type         => 'String',
			 is_optional  => 1,
			 doc          => "directory"
		    },

	    tier_1 => {
		          type        => 'String',
			  is_optional => 1,
			  doc         => "first tier value"
		       },

	    tier_2 => {
		          type        => 'String',
			  is_optional => 1,
			  doc         => "Second tier value"
		       },

	    major_contig_length => {
		                     type        => 'String',
				     is_optional => 1,
				     doc         => "Major contig length"
				    },

	    major_supercontig_length => {
		                          type        => 'String',
					  is_optional => 1,
					  doc         => "Major supercontig length"
					 },

	    output_file => {
		             type        => 'String',
			     is_optional => 1,
			     doc         => "Stats output file name"
			    },
	    ],
};

sub help_brief
{
    "runs newbler stats";
}

sub help_synopsis
{
    return <<EOS
gt newbler run-stats
EOS
}

sub help_detail
{
    return <<EOS
gt newbler run-stats --tier_1 <value> --tier_2 <value_2>
If est genome size is 1,000,000 bases, tier_1 is 500,000, tier_2 700,000
EOS
}

sub execute
{
    my ($self) = shift;
    unless ($self->validate)
    {
	$self->error_message("Failed to validate");
	return;
    }
    unless ($self->run_contig_stats)
    {
	$self->error_message("Failed to run stats");
	return;
    }
    return 1;
}

sub validate
{
    my ($self) = shift;

    #VALIDATE PROJECT DIRECTORY 
    my $project_dir = cwd();
    $project_dir = $self->dir if $self->dir;
    $self->error_message ("You must be in edit_dir") and return
	unless $project_dir =~ /edit_dir$/;
    $self->{project_dir} = $project_dir;

    #VALIDATE FILED NEEDED TO RUN STATS

    my @dir_files = glob ("$project_dir/*");

    #check for contigs.bases file
    $self->error_message ("No contigs.bases file") and return
	unless $self->{contigs_bases_file} = $project_dir.'/contigs.bases';

    #check for input files
    $self->error_message("No input fasta files found") and return
	unless @{$self->{input_fasta_files}} = grep (/fasta\.gz$/, @dir_files);
    $self->error_message ("No input qual files found") and return
	unless @{$self->{input_qual_files}} = grep (/fasta\.qual\.gz$/, @dir_files);

    #check for reads.placed file
    $self->error_message("No reads placed file") and return
	unless $self->{reads_placed_file} = $project_dir.'/reads.placed';

    #VALIDATE TIER VALUES
    if ($self->tier_1 or $self->tier_2)
    {
	$self->error_message("must define both tier_1 and tier_2 values") and return
	    unless $self->tier_1 and $self->tier_2;
	$self->error_message("tier_1 value must be less than tier_2 value") and return
	    unless $self->tier_2 > $self->tier_1;
	$self->{tier_one} = $self->tier_1;
	$self->{tier_two} = $self->tier_2 - $self->tier_1;	
    }
    else
    {
	#estimate tier values based on size of contigs.bases file
	my $file = $self->{project_dir}.'/contigs.bases';
	$self->error_message("You must have a contigs.bases file") and return
	    unless my $size = -s $file;
	#tier values estimated is tier_1 50% of contigs.bases file size, %20 for tier_two
	$self->{tier_one} = int ($size * 0.50);
	$self->{tier_two} = int ($size * 0.20);
    }

    #VALIDATE MAJOR CONTIG AND SUPERCONTIG LENGTHS
    $self->{major_ctg_length} = 500;
    $self->{major_ctg_length} = $self->major_contig_length
	if $self->major_contig_length;

    $self->{major_sctg_length} = 500;
    $self->{major_sctg_length} = $self->major_supercontig_length
	if $self->major_supercontig_length;

    return 1;
}

sub run_contig_stats
{
    my ($self) = shift;

    my $dir = $self->{project_dir};

    my $GC_num = 0;
    my $AT_num = 0;
    my $NX_num = 0;
    my $total_ctg_length = 0;

    my $cb_fh = IO::File->new("< $self->{contigs_bases_file}");
    while (my $line = $cb_fh->getline)
    {
	next if ($_ =~ /^>/);
	chomp();
	my @bases = split(//, $_);
	foreach my $b (@bases)
	{
	    $total_ctg_length++;
	    if($b =~ /[g,c]/i) { $GC_num++; }
	    elsif($b =~ /[a,t]/i) { $AT_num++; }
	    else { $NX_num++; }
	}
    }
    $cb_fh->close;

    my $total_input_reads;
    my $total_input_read_bases;
    my $total_Q20_bases;
    my $ave_Q20_bases_per_read;
    my $ave_input_read_length;
    my $unplaced_reads = 0;
    my $total_prefin_reads = 0;
    my $unplaced_prefin_reads = 0;
    my $reads_in_scaf = 0;
    
    foreach my $file ( @{$self->{input_qual_files}} )
    {
	my $fh = IO::File->new("zcat $file |");
	while (my $line = $fh->getline)
	{
	    chomp();
	    if($line =~ /^>/) 
	    {
		$total_input_reads++;
		my ($read_name) = $line =~ /^>(\S+)/;
		$total_prefin_reads++ if $read_name =~ /_t/;
	    }
	    else
	    {
		my @tmp = split(' ', $line);
		foreach my $item (@tmp)
		{
		    $total_input_read_bases++;
		    $total_Q20_bases++ if $item >=20;
		}
	    }
	}
	$fh->close;
    }

    my $rp_fh = IO::File->new("< $self->{reads_placed_file}");
    my $unique_read_names = {};
    while (my $line = $rp_fh->getline)
    {
	next if $line =~ /^\s+$/;
	$reads_in_scaf++;
	my ($read_name) = $line =~ /^\*\s+(\S+)\s+/;
	$read_name =~ s/[\.|\_].*$//;
	$unique_read_names->{$read_name} = 1;
    }
    $rp_fh->close;
    my $unique_reads_in_scaf = scalar (keys %$unique_read_names);
    $unique_read_names = '';
    
    $unplaced_reads = $total_input_reads - $unique_reads_in_scaf;
    
    $ave_Q20_bases_per_read = int($total_Q20_bases / $total_input_reads + 0.5);
    $ave_input_read_length = int($total_input_read_bases / $total_input_reads + 0.5);

    my $placed_reads = $total_input_reads - $unplaced_reads;
    my $duplicate_reads = $reads_in_scaf - $unique_reads_in_scaf;
    my $chaff_rate = int($unplaced_reads * 10000 / $total_input_reads + 0.5)/100;
    my $q20_redundancy = int($total_Q20_bases * 10 / $total_ctg_length)/10;

    my $stats;

    $stats=  "\n*** SIMPLE READ STATS ***\n".
             "Total input reads: $total_input_reads\n".
	     "Total input bases: $total_input_read_bases bp\n".
	     "Total Q20 bases: $total_Q20_bases bp\n".
	     "Average Q20 bases per read: $ave_Q20_bases_per_read bp\n".
	     "Average read length: $ave_input_read_length bp\n".
	     "Placed reads: $placed_reads\n".
	     "  (total reads in scaffold: $reads_in_scaf)\n".
	     "  (unique reads: $unique_reads_in_scaf)\n".
	     "  (duplicate reads: $duplicate_reads)\n".
	     "Unplaced reads: $unplaced_reads\n".
	     "Chaff rate: $chaff_rate %\n".
	     "Q20 base redundancy: $q20_redundancy X\n".
	     "Total prefin reads input: $total_prefin_reads\n".
	     "Total prefin reads unused: $unplaced_prefin_reads\n\n";

    my $tier1 = $self->{tier_one};
    my $tier2 = $self->{tier_two};

    my $major_ctg_length = $self->{major_ctg_length};
    my $major_sctg_length = $self->{major_sctg_length};

    my $q20bases;
    
    my $total_ctg_num;
    $total_ctg_length = 0;
    my $max_ctg_length = 0;
    my $major_ctg_num = 0;
    my $ave_ctg_length;
    my $N50_ctg_length;
    my $N50_ctg_num;
    my %ctg_length = ();
    my %ctg_q20base = ();
    
    my %sctg_length = ();
    my %sctg_q20base = ();
    
    my $total_sctg_num;
    my $ave_sctg_length;
    my $max_sctg_length = 0;
    my $major_sctg_num = 0;
    my $N50_sctg_length;
    my $N50_sctg_num;

    my $tier1sum = 0; my $tier1num = 0;
    my $tier2sum = 0; my $tier2num = 0;
    my $tier3sum = 0; my $tier3num = 0;
    my $largest_tier1 = 0;
    my $largest_tier2 = 0;
    my $largest_tier3 = 0;
    my $cummulative_length = 0;
    my $not_reached_yet = 1;
    
    my $t1_ctg_base = 0;
    my $t2_ctg_base = 0;
    my $t3_ctg_base = 0;
    my $t1_q20base = 0;
    my $t2_q20base = 0;
    my $t3_q20base = 0;
    
    my $t1_sctg_base = 0;
    my $t2_sctg_base = 0;
    my $t3_sctg_base = 0;
    my $t1_sq20base = 0;
    my $t2_sq20base = 0;
    my $t3_sq20base = 0;
    
    my $t1_N50_ctg_num;
    my $t1_N50_ctg_length;
    my $t2_N50_ctg_num;
    my $t2_N50_ctg_length;
    my $t3_N50_ctg_num;
    my $t3_N50_ctg_length;
    
    my $t1_N50_sctg_num;
    my $t1_N50_sctg_length;
    my $t2_N50_sctg_num;
    my $t2_N50_sctg_length;
    my $t3_N50_sctg_num;
    my $t3_N50_sctg_length;
    
    my $t1_not_reached_yet = 1;
    my $t2_not_reached_yet = 1;
    my $t3_not_reached_yet = 1;
    
    my $major_ctg_bases;
    my $major_ctg_q20_bases;
    my $major_sctg_bases;
    my $major_sctg_q20_bases;
    
    my $larger_than_1M_scaf = 0;
    my $larger_than_250K_scaf = 0;
    my $larger_than_100K_scaf = 0;
    my $larger_than_10K_scaf = 0;
    my $larger_than_5K_scaf = 0;
    my $larger_than_2K_scaf = 0;
    my $larger_than_0K_scaf = 0;
    
    my $sctg_name;
    my $ctg_name;

    my $iq_fh = IO::File->new("< $self->{contigs_quals_file}");
    while (my $line = $iq_fh->getline)
    {
	chomp();
	if($line =~ /^>/)
	{
	    $total_ctg_num++;
	    ($ctg_name) = $line =~ /Contig(\d+\.\d+)/;
	    ($sctg_name) = $line =~ /Contig(\d+)\.\d+/;
	}
	else
	{
	    my @tmp = split(' ', $line);
	    foreach my $item (@tmp)
	    {
		if($item >=20) 
		{
		    $q20bases++; 
		    $ctg_q20base{$ctg_name}++;
		    $sctg_q20base{$sctg_name}++;
		}
		$total_ctg_length++;
		$ctg_length{$ctg_name}++;
		$sctg_length{$sctg_name}++;
	    }
	}
    }

    $iq_fh->close;

    $ave_ctg_length = int($total_ctg_length / $total_ctg_num + 0.5);
    my $tier3 = $total_ctg_length - $tier1 - $tier2;

    foreach my $c (sort {$ctg_length{$b} <=> $ctg_length{$a}} keys %ctg_length)
    {
    	if($ctg_length{$c} > $major_ctg_length)
	{
	    $major_ctg_num++;
	    $major_ctg_bases += $ctg_length{$c};
	    $major_ctg_q20_bases += $ctg_q20base{$c};
	}
	
	$cummulative_length += $ctg_length{$c};
	
	$N50_ctg_num++ if $not_reached_yet;
	
	$max_ctg_length = $ctg_length{$c} if $ctg_length{$c} > $max_ctg_length;
	
	if($not_reached_yet && ($cummulative_length >= ($total_ctg_length * 0.50)))
	{
	    $N50_ctg_length = $ctg_length{$c};
	    $not_reached_yet = 0;
	}
	
	if($tier1sum < $tier1)
	{
	    if($t1_not_reached_yet) 
	    { 
		$t1_N50_ctg_num++; 
	    }	
	    
	    $tier1sum += $ctg_length{$c};
	    $tier1num++;
	    $largest_tier1 = $ctg_length{$c} if($largest_tier1 == 0);
	    
	    if($t1_not_reached_yet && ($cummulative_length >= ($tier1 * 0.50)))
	    {
		$t1_N50_ctg_length = $ctg_length{$c};
		$t1_not_reached_yet = 0;
	    }
	    $t1_ctg_base += $ctg_length{$c};
	    $t1_q20base += $ctg_q20base{$c};
	    
	}
	elsif($tier2sum < $tier2)
	{
	    if($t2_not_reached_yet) 
	    { 
		$t2_N50_ctg_num++; 
	    }	
	
	    $tier2sum += $ctg_length{$c};
	    $tier2num++;
	    $largest_tier2 = $ctg_length{$c} if($largest_tier2 == 0);
	    
	    if($t2_not_reached_yet && (($cummulative_length - $tier1) >= ($tier2 * 0.50)))
	    {
		$t2_N50_ctg_length = $ctg_length{$c};
		$t2_not_reached_yet = 0;
	    }
	    
	    $t2_ctg_base += $ctg_length{$c};
	    $t2_q20base += $ctg_q20base{$c};
	}
	else
	{
	    if($t3_not_reached_yet) 
	    { 
		$t3_N50_ctg_num++; 
	    }	
	    
	    $tier3sum += $ctg_length{$c};
	    $tier3num++;
	    $largest_tier3 = $ctg_length{$c} if($largest_tier3 == 0);
	    
	    if($t3_not_reached_yet && (($cummulative_length - $tier1 - $tier2) >= ($tier3 * 0.50)))
	    {
		$t3_N50_ctg_length = $ctg_length{$c};
		$t3_not_reached_yet = 0;
	    }
	    
	    $t3_ctg_base += $ctg_length{$c};
	    $t3_q20base += $ctg_q20base{$c};
	}
    }

#need to iterate through this again for some N50 specific stats
    my $N50_not_yet_reached = 1;
    my $N50_cummulative_length = 0;
    my $maj_ctg_N50_ctg_num = 0;
    my $maj_ctg_N50_ctg_length = 0;
    foreach my $c (sort {$ctg_length{$b} <=> $ctg_length{$a}} keys %ctg_length)
    {
	next unless $ctg_length{$c} > $major_ctg_length;
	$N50_cummulative_length += $ctg_length{$c};
	$maj_ctg_N50_ctg_num++ if $N50_not_yet_reached;
	if ( $N50_not_yet_reached and $N50_cummulative_length >= ($major_ctg_bases * 0.50) )
	{
	    $N50_not_yet_reached = 0;
	    $maj_ctg_N50_ctg_length = $ctg_length{$c};
	}
    }

    my $Q20_base_ratio = int($q20bases * 1000 / $total_ctg_length) / 10;

    $stats .= "\n*** Contiguity: Contig ***\n".
	      "Total contig number: $total_ctg_num\n".
	      "Total contig bases: $total_ctg_length bp\n".
	      "Total Q20 bases: $q20bases bp\n".
	      "Q20 bases %: $Q20_base_ratio"."%\n".
	      "Average contig length: $ave_ctg_length bp\n".
	      "Maximum contig length: $max_ctg_length bp\n".
	      "N50 contig length: $N50_ctg_length bp\n".
	      "N50 contig number: $N50_ctg_num\n\n";
    
    my $maj_ctg_avg_ctg_length = int ($major_ctg_bases/$major_ctg_num);
    my $maj_ctg_q20_ratio = (int ($major_ctg_q20_bases * 1000 / $major_ctg_bases + 0.5) ) /10;

    $stats .= "Major contig (> $major_ctg_length bp) number: $major_ctg_num\n".
	      "Major_contig bases: $major_ctg_bases bp\n".
	      "Major_contig avg contig length: $maj_ctg_avg_ctg_length\n".
	      "Major_contig Q20 bases: $major_ctg_q20_bases bp\n".
	      "Major_contig Q20 base percent: $maj_ctg_q20_ratio"."%\n".
	      "Major_contig N50 contig length: $maj_ctg_N50_ctg_length\n".
	      "Major_contig N50 contig number: $maj_ctg_N50_ctg_num\n\n";
    
    my $ctg_top_tier_avg_lenth = int($tier1sum/$tier1num + 0.5);
    my $ctg_top_tier_q20_base_ratio = (int($t1_q20base * 1000 /$t1_ctg_base))/10;

    $stats .= "Top tier (up to $tier1 bp): \n".
	      "  Contig number: $tier1num\n".
	      "  Average length: $ctg_top_tier_avg_lenth bp\n".
	      "  Longest length: $largest_tier1 bp\n".
	      "  Contig bases in this tier: $t1_ctg_base bp\n".
	      "  Q20 bases in this tier: $t1_q20base bp\n".
	      "  Q20 base percentage: $ctg_top_tier_q20_base_ratio"."%\n".
	      "  Top tier N50 contig length: $t1_N50_ctg_length bp\n".
	      "  Top tier N50 contig number: $t1_N50_ctg_num\n\n";
    
    my $ctg_mid_tier_value = $tier1 + $tier2;
    my $ctg_mid_tier_avg_length = int($tier2sum/$tier2num + 0.5);
    my $ctg_mid_tier_q20_base_ratio = (int($t2_q20base * 1000 /$t2_ctg_base))/10;

    $stats .= "Middle tier ($tier1 bp .. $ctg_mid_tier_value bp):\n".
              "  Contig number: $tier2num\n".
	      "  Average length: $ctg_mid_tier_avg_length bp\n".
	      "  Longest length: $largest_tier2 bp\n".
	      "  Contig bases in this tier: $t2_ctg_base bp\n".
	      "  Q20 bases in this tier: $t2_q20base bp\n".
	      "  Q20 base percentage: $ctg_mid_tier_q20_base_ratio"."%\n".
	      "  Middle tier N50 contig length: $t2_N50_ctg_length bp\n".
	      "  Middle tier N50 contig number: $t2_N50_ctg_num\n\n";

    my $ctg_low_tier_value = $tier1 + $tier2;
    my $ctg_low_tier_avg_length = int($tier3sum/$tier3num + 0.5);
    my $ctg_low_tier_q20_base_ratio = (int($t3_q20base * 1000 /$t3_ctg_base))/10;

    $stats .= "Bottom tier ( $ctg_low_tier_value bp -- end ): \n".
	      "  Contig number: $tier3num\n".
	      "  Average length: $ctg_low_tier_avg_length bp\n".
	      "  Longest length: $largest_tier3 bp\n".
	      "  Contig bases in this tier: $t3_ctg_base bp\n".
	      "  Q20 bases in this tier: $t3_q20base bp\n".
	      "  Q20 base percentage: $ctg_low_tier_q20_base_ratio"."%\n".
	      "  Bottom tier N50 contig length: $t3_N50_ctg_length bp\n".
	      "  Bottom tier N50 contig number: $t3_N50_ctg_num\n\n";

    
#3. Contiguity: Supercontig stats
    $tier1sum = 0; $tier1num = 0;
    $tier2sum = 0; $tier2num = 0;
    $tier3sum = 0; $tier3num = 0;
    $largest_tier1 = 0;
    $largest_tier2 = 0;
    $largest_tier3 = 0;
    $cummulative_length = 0;
    $not_reached_yet = 1;
    
    $t1_not_reached_yet = 1;
    $t2_not_reached_yet = 1;
    $t3_not_reached_yet = 1;
    
    foreach my $sc (sort {$sctg_length{$b} <=> $sctg_length{$a}} keys %sctg_length)
    {
	$total_sctg_num++;
	
	if($sctg_length{$sc} > 1000000) {$larger_than_1M_scaf++;}
	elsif($sctg_length{$sc} > 250000) {$larger_than_250K_scaf++;}
	elsif($sctg_length{$sc} > 100000) {$larger_than_100K_scaf++;}
	elsif($sctg_length{$sc} > 10000) {$larger_than_10K_scaf++;}	
	elsif($sctg_length{$sc} > 5000) {$larger_than_5K_scaf++;}
	elsif($sctg_length{$sc} > 2000) {$larger_than_2K_scaf++;}
	else {$larger_than_0K_scaf++;}
	
	if($sctg_length{$sc} > $major_sctg_length)
	{
	    $major_sctg_bases += $sctg_length{$sc};
	    $major_sctg_q20_bases += $sctg_q20base{$sc};
	}
	
	$cummulative_length += $sctg_length{$sc};
	
	if($not_reached_yet) { $N50_sctg_num++; }
	
	if($sctg_length{$sc} > $max_sctg_length)
	{
	    $max_sctg_length = $sctg_length{$sc};
	}
	
	if($sctg_length{$sc} >= $major_sctg_length)
	{
	    $major_sctg_num++;
	}
	
	if($not_reached_yet && ($cummulative_length >= ($total_ctg_length * 0.50)))
	{
	    $N50_sctg_length = $sctg_length{$sc};
	    $not_reached_yet = 0;
	}
	
	if($tier1sum < $tier1)
	{
	    if($t1_not_reached_yet) { $t1_N50_sctg_num++; }	
	    
	    $tier1sum += $sctg_length{$sc};
	    $tier1num++;
	    $largest_tier1 = $sctg_length{$sc} if($largest_tier1 == 0);
	    
	    if($t1_not_reached_yet && (($cummulative_length) >= ($tier1 * 0.50)))
	    {
		$t1_N50_sctg_length = $sctg_length{$sc};
		$t1_not_reached_yet = 0;
	    }
	    
	    $t1_sctg_base += $sctg_length{$sc};
	    $t1_sq20base += $sctg_q20base{$sc};
	}
	elsif($tier2sum < $tier2)
	{
	    if($t2_not_reached_yet) { $t2_N50_sctg_num++; }	
	    
	    $tier2sum += $sctg_length{$sc};
	    $tier2num++;
	    $largest_tier2 = $sctg_length{$sc} if($largest_tier2 == 0);
	    
	    if($t2_not_reached_yet && (($cummulative_length - $tier1) >= ($tier2 * 0.50)))
	    {
		$t2_N50_sctg_length = $sctg_length{$sc};
		$t2_not_reached_yet = 0;
	    }
	    
	    $t2_sctg_base += $sctg_length{$sc};
	    $t2_sq20base += $sctg_q20base{$sc};
	}
	else
	{
	    if($t3_not_reached_yet) { $t3_N50_sctg_num++; }	
	    
	    $tier3sum += $sctg_length{$sc};
	    $tier3num++;
	    $largest_tier3 = $sctg_length{$sc} if($largest_tier3 == 0);
	    
	    if($t3_not_reached_yet && (($cummulative_length - $tier1 - $tier2) >= ($tier3 * 0.50)))
		{
		    $t3_N50_sctg_length = $sctg_length{$sc};
		    $t3_not_reached_yet = 0;
		}
		
	    $t3_sctg_base += $sctg_length{$sc};
	    $t3_sq20base += $sctg_q20base{$sc};
	}
    }
    $ave_sctg_length = int($total_ctg_length / $total_sctg_num + 0.5);
    
    $N50_not_yet_reached = 1;
    $N50_cummulative_length = 0;
    my $maj_sctg_N50_ctg_num = 0;
    my $maj_sctg_N50_ctg_length = 0;
    
    foreach my $sc (sort {$sctg_length{$b} <=> $sctg_length{$a}} keys %sctg_length)
    {
	next unless $sctg_length{$sc} > $major_sctg_length;
	$N50_cummulative_length += $sctg_length{$sc};
	$maj_sctg_N50_ctg_num++ if $N50_not_yet_reached;
	if ( $N50_not_yet_reached and $N50_cummulative_length >= ($major_sctg_bases * 0.50) )
	{
	    $N50_not_yet_reached = 0;
	    $maj_sctg_N50_ctg_length = $sctg_length{$sc};
	}
    }

    $stats .= "\n*** Contiguity: Supercontig ***\n".
	      "Total supercontig number: $total_sctg_num\n".
	      "Average supercontig length: $ave_sctg_length bp\n".
	      "Maximum supercontig length: $max_sctg_length bp\n".
	      "N50 supercontig length: $N50_sctg_length bp\n".
	      "N50 supercontig number: $N50_sctg_num\n\n";
    
    my $maj_sctg_avg_length = int($major_sctg_bases / $major_sctg_num);
    my $maj_sctg_q20_base_ratio = (int($major_sctg_q20_bases * 1000 / $major_sctg_bases + 0.5))/10;

    $stats .= "Major supercontig (> $major_sctg_length bp) number: $major_sctg_num\n".
	      "Major_supercontig bases: $major_sctg_bases bp\n".
	      "Major_supercontig avg contig length: $maj_sctg_avg_length\n".
	      "Major_supercontig Q20 bases: $major_sctg_q20_bases bp\n".
	      "Major_supercontig Q20 base percent: $maj_sctg_q20_base_ratio"."%\n".
	      "Major_supercontig N50 contig length: $maj_sctg_N50_ctg_length\n".
	      "Major_supercontig N50 contig number: $maj_sctg_N50_ctg_num\n\n";
    
    $stats .= "Scaffolds > 1M: $larger_than_1M_scaf\n".
	      "Scaffold 250K--1M: $larger_than_250K_scaf\n".
	      "Scaffold 100K--250K: $larger_than_100K_scaf\n".
	      "Scaffold 10--100K: $larger_than_10K_scaf\n".
	      "Scaffold 5--10K: $larger_than_5K_scaf\n".
	      "Scaffold 2--5K: $larger_than_2K_scaf\n".
	      "Scaffold 0--2K: $larger_than_0K_scaf\n\n";
    
    my $sctg_top_tier_avg_length = int($tier1sum/$tier1num + 0.5);
    my $sctg_top_tier_q20_base_ratio = (int($t1_sq20base * 1000 /$t1_sctg_base))/10;

    $stats .= "Top tier (up to $tier1 bp): \n".
              "  Supercontig number: $tier1num\n".
	      "  Average length: $sctg_top_tier_avg_length bp\n".
	      "  Longest length: $largest_tier1 bp\n".
	      "  Contig bases in this tier: $t1_sctg_base bp\n".
	      "  Q20 bases in this tier: $t1_sq20base bp\n".
	      "  Q20 base percentage: $sctg_top_tier_q20_base_ratio"."%\n".
	      "  Top tier N50 supercontig length: $t1_N50_sctg_length bp\n".
	      "  Top tier N50 supercontig number: $t1_N50_sctg_num\n\n";
    
    my $sctg_mid_tier_value = $tier1 + $tier2;
    my $sctg_mid_tier_avg_length = int($tier2sum/$tier2num + 0.5);
    my $sctg_mid_tier_q20_base_ratio = (int($t2_sq20base * 1000 /$t2_sctg_base))/10;

    $stats .= "Middle tier ($tier1 bp -- $sctg_mid_tier_value bp): \n".
	      "  Supercontig number: $tier2num\n".
	      "  Average length: $sctg_mid_tier_avg_length bp\n".
	      "  Longest length: $largest_tier2 bp\n".
	      "  Contig bases in this tier: $t2_sctg_base bp\n".
	      "  Q20 bases in this tier: $t2_sq20base bp\n".
	      "  Q20 base percentage: $sctg_mid_tier_q20_base_ratio"."%\n".
	      "  Middle tier N50 supercontig length: $t2_N50_sctg_length bp\n".
	      "  Middle tier N50 supercontig number: $t2_N50_sctg_num\n\n";
	      
    my $sctg_low_tier_value = $tier1 + $tier2;
    my $sctg_low_tier_avg_length = int($tier3sum/$tier3num + 0.5);
    my $sctg_low_tier_q20_base_ratio = (int($t3_sq20base * 1000 /$t3_sctg_base))/10;

    $stats .= "Bottom tier ( $sctg_low_tier_value bp .. end): \n".
	      "  Supercontig number: $tier3num\n".
	      "  Average length: $sctg_low_tier_avg_length bp\n".
	      "  Longest length: $largest_tier3 bp\n".
	      "  Contig bases in this tier: $t3_sctg_base bp\n".
	      "  Q20 bases in this tier: $t3_sq20base bp\n".
	      "  Q20 base percentage: $sctg_low_tier_q20_base_ratio"."%\n".
	      "  Bottom tier N50 supercontig length: $t3_N50_sctg_length bp\n".
	      "  Bottom tier N50 supercontig number: $t3_N50_sctg_num\n\n";

###############
# CONSTRAINTS #
###############

    $stats .= "\n*** Constraints ***\n".
	      "No constraint info for newbler assemblies\n\n";

    my $GC_ratio = int(1000 * $GC_num/$total_ctg_length + 0.5) / 10;
    my $AT_ratio = int(1000 * $AT_num/$total_ctg_length + 0.5) / 10;
    my $NX_ratio = int(1000 * $NX_num/$total_ctg_length + 0.5) / 10;

    $stats .= "\n\n*** Genome Contents ***\n".
	      "Total GC count: $GC_num, (".$GC_ratio."%)\n".
	      "Total AT count: $AT_num, (".$AT_ratio."%)\n".
	      "Total NX count: $NX_num, (".$NX_ratio."%)\n".
	      "Total: $total_ctg_length\n\n";


############################
# CORE GENE SURVEY RESULTS #
############################

    $stats .= "\n*** Core Gene survey Result ***\n";
    
    if (-s 'Cov_30_PID_30.out.gz')
    {
	my $fh = IO::File->new("zcat Cov_30_PID_30.out.gz |");
	while (my $line = $fh->getline)
	{
	    $stats .= $line if $line =~ /^Perc/;
	    $stats .= $line if $line =~ /^Number/;
	    $stats .= $line if $line =~ /^Core/;
	}
	$fh->close;
	$stats .= "\n";
    }
    else
    {
	$stats .= "Cov_30_PID_30.out.gz missing .. unable to create core gene survey results\n\n";
    }
    

###################
# READ DEPTH INFO #
###################

    $stats .= "\n*** Read Depth Info ***\n";
    
    if (-s '../../454AlignmentInfo.tsv' and -s 'contigs.bases')
    {
    #get total base lenghts
	my $f_fh = IO::File->new("< contigs.bases");
	my $f_io = Bio::SeqIO->new(-format => 'fasta', -fh => $f_fh);
	my $total_length = 0;
	while (my $f_seq = $f_io->next_seq)
	{
	    $total_length += length $f_seq->seq;
	}
#   print $total_length."\n";
	$f_fh->close;
	
	$f_io = '';
	
	my $ref_length = $total_length;
	
	my ($depth1, $depth2, $depth3, $depth4, $depth5) = 0;
	my ($contig, %rpos);
	
	my $fh = IO::File->new("< ../../454AlignmentInfo.tsv");
	while (my $line = $fh->getline)
	{
	    next if $line =~ /^Position/; #ignore the header line
	    my ($base, $pos, $depth);
	    if ($line =~ /^>/)
	    {
		($contig) = $line =~ /^>(\S+)/;
		next;
	    }

	    my @ar = split (/\s+/, $line);
	    $base = $ar[1]; #base
	    $pos = $ar[0]; #base contig position
	    $depth = $ar[3]; #depth of bases at that position

	    next if $base =~ /\-/;
	    if ($depth >= 5)
	    {
		$depth5++; $depth4++; $depth3++; $depth2++; $depth1++;
	    }
	    elsif ($depth >= 4)
	    {
		$depth4++; $depth3++; $depth2++; $depth1++;
	    }
	    elsif ($depth >= 3)
	    {
		$depth3++; $depth2++; $depth1++;
	    }
	    elsif ($depth >= 2)
	    {
		$depth2++; $depth1++;
	    }
	    elsif ($depth >= 1)
	    {
		$depth1++;
	    }
	    else
	    {
		$stats .= "ERROR: depth at contig $contig position $pos is $depth\n";
	    }
	    
	    
	    if (defined $rpos{$contig}[$pos])
	    {
		$rpos{$contig}[$pos] += 1;
		$stats .= "ERROR $contig $pos $rpos{$contig}[$pos]\n";
	    }
	    else
	    {
		$rpos{$contig}[$pos] = 1;
	    }
	    
	}
	$fh->close;

	my $p5 = $depth5 / $ref_length;
	my $p4 = $depth4 / $ref_length;
	my $p3 = $depth3 / $ref_length;
	my $p2 = $depth2 / $ref_length;
	my $p1 = $depth1 / $ref_length;
	my $depth0 = $ref_length - $depth1;
	my $p0 = $depth0 / $ref_length;
	
	$stats .= "Reads depth information:\nreference length: $ref_length\n".
	          "depth >= 5: $depth5\t$p5\n".
		  "depth >= 4: $depth4\t$p4\n".
		  "depth >= 3: $depth3\t$p3\n".
		  "depth >= 2: $depth2\t$p2\n".
		  "depth >= 1: $depth1\t$p1\n".
		  "not covered bases: $depth0\t$p0\n\n";
	
    }
    else
    {
	$stats .= "../../454AlignmentInfo.tsv and or contigs.bases files do not exist or are blank\n".
	          "skipping ..\n\n";
    }
    
#####################
# 5 KB CONTIGS INFO #
#####################


    $stats .= "\n\n*** 5 Kb and Greater Contigs Info ***\n";
    
    if (-s 'contigs.bases')
    {
	my $total_ctg_lengths = 0;
	my $five_kb_ctg_lengths = 0;
	
	my $cb_fh = IO::File->new("< contigs.bases");
	my $fio = Bio::SeqIO->new(-format => 'fasta', -fh => $cb_fh);
	while (my $f_seq = $fio->next_seq)
	{
	    my $ctg_length = length $f_seq->seq;
	    $total_ctg_lengths += $ctg_length;
	    if ($ctg_length >= 5000)
	    {
		$five_kb_ctg_lengths += $ctg_length;
	    }
	}
	$cb_fh->close;
	
	my $ratio = 0;
	
	if ($five_kb_ctg_lengths > 0)
	{
	    $ratio = int ($five_kb_ctg_lengths / $total_ctg_lengths * 100);
	}
	
	$stats .= "Total lengths of all contigs: $total_ctg_lengths\n".
	          "Total lengths of contigs 5 Kb and greater: $five_kb_ctg_lengths\n".
		  "Percentage of genome: $ratio%\n";
	
    }
    else
    {
	$stats .= "contigs.bases file missing\n".
	          "unable to determine 5 kb contigs stats\n";
    }
    return 1;
}
