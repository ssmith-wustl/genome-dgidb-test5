package Genome::Model::Tools::Assembly::Stats::Velvet;

use strict;
use warnings;

use Genome;
use Cwd;
class Genome::Model::Tools::Assembly::Stats::Velvet {
    is => ['Genome::Model::Tools::Assembly::Stats'],
    has => [
	    first_tier => {
		type => 'int non_neg',
		is_optional => 1,
		doc => "first tier value",
	        },
	    second_tier => {
		type => 'int non_neg',
		is_optional => 1,
		doc => "second tier value",
	        },
	    assembly_directory => {
		type => 'String',
		is_optional => 1,
		doc => "path to assembly"
		},
	    ],
};

sub help_brief {
    'Run stats on velvet assemblies'
}

sub help_detail {
    return <<"EOS"
Run stats on velvet assemblies
EOS
}

sub execute {
    my ($self) = @_;

    my $usage = "More later .. ";

    my $dir;
    if ($self->assembly_directory) {
	$dir = $self->assembly_directory;
    }
    else {
	$dir = cwd();
    }

#user can either input both values or not input
#anything and have the script figure it out
#based on the size of the contigs.bases file

#    print $usage and exit (1) if scalar @ARGV == 1;
#    print $usage and exit (1) if scalar @ARGV > 2;

    my ($tier1, $tier2);
    my $est_size = -s $dir.'/contigs.bases';

    if ($self->first_tier) {
	$tier1 = $self->first_tier;
    }
    else {
	$tier1 = int ($est_size * 0.6);
    }

    if ($self->second_tier) {
	$tier2 = $self->second_tier;
    }
    else {
	$tier2 = int ($est_size * 0.2);
    }

#my $tier1 = $ARGV[0] or die $usage;
#my $tier2 = $ARGV[1] or die $usage;

    my $fosmid_prefix = $ARGV[2];
    my $major_ctg_length = 500;
    my $major_sctg_length = 500;
    
    $dir .= "/";
#print "$dir\n\n";

#total base
    my $GC_num = 0;
    my $AT_num = 0;
    my $NX_num = 0;
    my $total_ctg_length = 0;

    opendir (D, $dir) or die "Cannot open $dir directory.\n";
    my @files = readdir (D);

    foreach my $file (@files)
    {
	next unless ($file =~ /contigs\.bases$/);
	$file = $dir.$file;
	open(F, "$file") or die "Cannot open $file.\n";
	while(<F>)
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
	close(F);
    }


#reads info
    my $total_input_reads;
    my $total_input_read_bases;
    my $total_Q20_bases;
    my $ave_Q20_bases_per_read;
    my $ave_input_read_length;
    my $unplaced_reads = 0;
    my $total_prefin_reads = 0;
    my $unplaced_prefin_reads = 0;
    my $reads_in_scaf = 0;
    
    foreach my $file (@files)
    {
	next unless ($file =~ /qual\.gz/); 
	$file = $dir.$file;
	if($file =~ /gz$/) { open(F, "zcat $file |") or die "Cannot open $file.\n"; }
	else { open(F, $file) or die "Cannot open $file.\n"; }
	while(<F>)
	{
	    chomp();
	    if($_ =~ /^>/) 
	    {
		$total_input_reads++;
		
		my ($read_name) = $_ =~ /^>(\S+)/;
		if($read_name =~ /_t/) { $total_prefin_reads++; }	
	    }
	    else
	    {
		my @tmp = split(' ', $_);
		foreach my $item (@tmp)
		{
		    $total_input_read_bases++;
		    if($item >=20) { $total_Q20_bases++; }
		}
	    }
	}
	close(F);
    }

#contiguity
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

    foreach my $file (@files)
    {
	next unless ($file =~ /contigs\.qual/);
	$file = $dir.$file;
	if($file =~ /gz$/) { open(F, "zcat $file |") or die "Cannot open $file.\n"; }
	else { open(F, $file) or die "Cannot open $file.\n"; }
	my $sctg_name;
	my $ctg_name;
#	open(F, $file) or die "Cannot open $file.\n";
	while(<F>)
	{
	    chomp();
	    if($_ =~ /^>/)
	    {
		$total_ctg_num++;
		($ctg_name) = $_ =~ /Contig(\d+\.\d+)/;
		($sctg_name) = $_ =~ /Contig(\d+)\.\d+/;
	    }
	    else
	    {
		my @tmp = split(' ', $_);
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
	close(F);
    }
    $ave_ctg_length = int($total_ctg_length / $total_ctg_num + 0.5);
    my $tier3 = $total_ctg_length - $tier1 - $tier2;

    foreach my $c (sort {$ctg_length{$b} <=> $ctg_length{$a}} keys %ctg_length)
    {

	if($ctg_length{$c} > $major_ctg_length)
	{
	    $major_ctg_bases += $ctg_length{$c};
	    $major_ctg_q20_bases += $ctg_q20base{$c};
	}
	
	$cummulative_length += $ctg_length{$c};
	
	if($not_reached_yet) { $N50_ctg_num++; }
	
	if($ctg_length{$c} > $max_ctg_length)
	{
	    $max_ctg_length = $ctg_length{$c};
	}
	
	if($ctg_length{$c} >= $major_ctg_length)
	{
	    $major_ctg_num++;
	}
	
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
    
    print "\n*** Contiguity: Contig ***\n";
    print "Total contig number: $total_ctg_num\n";
    print "Total contig bases: $total_ctg_length bp\n";
    print "Total Q20 bases: $q20bases bp\n";
    print "Q20 bases %: ", int($q20bases*1000/$total_ctg_length)/10, "%\n";
    print "Average contig length: $ave_ctg_length bp\n";
    print "Maximum contig length: $max_ctg_length bp\n";
    print "N50 contig length: $N50_ctg_length bp\n";
    print "N50 contig number: $N50_ctg_num\n\n";

    print "Major contig (> $major_ctg_length bp) number: $major_ctg_num\n";
    print "Major_contig bases: $major_ctg_bases bp\n";
    print "Major_contig avg contig length: ",int ($major_ctg_bases/$major_ctg_num),"\n";
    print "Major_contig Q20 bases: $major_ctg_q20_bases bp\n";
    print "Major_contig Q20 base percent: ", (int($major_ctg_q20_bases * 1000 / $major_ctg_bases + 0.5))/10, "%\n";
    print "Major_contig N50 contig length: $maj_ctg_N50_ctg_length\n";
    print "Major_contig N50 contig number: $maj_ctg_N50_ctg_num\n\n";

    print "Top tier (up to $tier1 bp): \n";
    print "  Contig number: $tier1num\n";
    print "  Average length: ", int($tier1sum/$tier1num + 0.5)," bp\n";
    print "  Longest length: $largest_tier1 bp\n";
    print "  Contig bases in this tier: $t1_ctg_base bp\n";
    print "  Q20 bases in this tier: $t1_q20base bp\n";
    print "  Q20 base percentage: ", (int($t1_q20base * 1000 /$t1_ctg_base))/10, "%\n";
    print "  Top tier N50 contig length: $t1_N50_ctg_length bp\n";
    print "  Top tier N50 contig number: $t1_N50_ctg_num\n\n";

    print "Middle tier ($tier1 bp -- ", $tier1+$tier2, " bp): \n";
    print "  Contig number: $tier2num\n";
    print "  Average length: ", int($tier2sum/$tier2num + 0.5)," bp\n";
    print "  Longest length: $largest_tier2 bp\n";
    print "  Contig bases in this tier: $t2_ctg_base bp\n";
    print "  Q20 bases in this tier: $t2_q20base bp\n";
    print "  Q20 base percentage: ", (int($t2_q20base * 1000 /$t2_ctg_base))/10, "%\n";
    print "  Middle tier N50 contig length: $t2_N50_ctg_length bp\n";
    print "  Middle tier N50 contig number: $t2_N50_ctg_num\n\n";

    print "Bottom tier (", $tier1+$tier2, " bp -- end): \n";
    print "  Contig number: $tier3num\n";
    print "  Average length: ", int($tier3sum/$tier3num + 0.5)," bp\n";
    print "  Longest length: $largest_tier3 bp\n";
    print "  Contig bases in this tier: $t3_ctg_base bp\n";
    print "  Q20 bases in this tier: $t3_q20base bp\n";
    print "  Q20 base percentage: ", (int($t3_q20base * 1000 /$t3_ctg_base))/10, "%\n";
    print "  Bottom tier N50 contig length: $t3_N50_ctg_length bp\n";
    print "  Bottom tier N50 contig number: $t3_N50_ctg_num\n\n";


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

    print "\n*** Contiguity: Supercontig ***\n";
    print "Total supercontig number: $total_sctg_num\n";
    print "Average supercontig length: $ave_sctg_length bp\n";
    print "Maximum supercontig length: $max_sctg_length bp\n";
    print "N50 supercontig length: $N50_sctg_length bp\n";
    print "N50 supercontig number: $N50_sctg_num\n\n";

    print "Major supercontig (> $major_sctg_length bp) number: $major_sctg_num\n";
    print "Major_supercontig bases: $major_sctg_bases bp\n";
    print "Major_supercontig avg contig length: ",int($major_sctg_bases / $major_sctg_num),"\n";
    print "Major_supercontig Q20 bases: $major_sctg_q20_bases bp\n";
    print "Major_supercontig Q20 base percent: ", (int($major_sctg_q20_bases * 1000 / $major_sctg_bases + 0.5))/10, "%\n";
    print "Major_supercontig N50 contig length: $maj_sctg_N50_ctg_length\n";
    print "Major_supercontig N50 contig number: $maj_sctg_N50_ctg_num\n\n";
    
    print "Scaffolds > 1M: $larger_than_1M_scaf\n";
    print "Scaffold 250K--1M: $larger_than_250K_scaf\n";
    print "Scaffold 100K--250K: $larger_than_100K_scaf\n";
    print "Scaffold 10--100K: $larger_than_10K_scaf\n";
    print "Scaffold 5--10K: $larger_than_5K_scaf\n";
    print "Scaffold 2--5K: $larger_than_2K_scaf\n";
    print "Scaffold 0--2K: $larger_than_0K_scaf\n\n";

    print "Top tier (up to $tier1 bp): \n";
    print "  Supercontig number: $tier1num\n";
    print "  Average length: ", int($tier1sum/$tier1num + 0.5)," bp\n";
    print "  Longest length: $largest_tier1 bp\n";
    print "  Contig bases in this tier: $t1_sctg_base bp\n";
    print "  Q20 bases in this tier: $t1_sq20base bp\n";
    print "  Q20 base percentage: ", (int($t1_sq20base * 1000 /$t1_sctg_base))/10, "%\n";
    print "  Top tier N50 supercontig length: $t1_N50_sctg_length bp\n";
    print "  Top tier N50 supercontig number: $t1_N50_sctg_num\n\n";
    
    print "Middle tier ($tier1 bp -- ", $tier1+$tier2, " bp): \n";
    print "  Supercontig number: $tier2num\n";
    print "  Average length: ", int($tier2sum/$tier2num + 0.5)," bp\n";
    print "  Longest length: $largest_tier2 bp\n";
    print "  Contig bases in this tier: $t2_sctg_base bp\n";
    print "  Q20 bases in this tier: $t2_sq20base bp\n";
    print "  Q20 base percentage: ", (int($t2_sq20base * 1000 /$t2_sctg_base))/10, "%\n";
    print "  Middle tier N50 supercontig length: $t2_N50_sctg_length bp\n";
    print "  Middle tier N50 supercontig number: $t2_N50_sctg_num\n\n";
    
    print "Bottom tier (", $tier1+$tier2, " bp -- end): \n";
    print "  Supercontig number: $tier3num\n";
    print "  Average length: ", int($tier3sum/$tier3num + 0.5)," bp\n";
    print "  Longest length: $largest_tier3 bp\n";
    print "  Contig bases in this tier: $t3_sctg_base bp\n";
    print "  Q20 bases in this tier: $t3_sq20base bp\n";
    print "  Q20 base percentage: ", (int($t3_sq20base * 1000 /$t3_sctg_base))/10, "%\n";
    print "  Bottom tier N50 supercontig length: $t3_N50_sctg_length bp\n";
    print "  Bottom tier N50 supercontig number: $t3_N50_sctg_num\n\n";


#constraints
#my $constraints = `tail -12 *.results`;
    print "\n*** Constraints ***\n";
    print "No constraint info for newbler assemblies\n\n";
#print "$constraints\n";

    print "\n*** Genome Contents ***\n";
    print "Total GC count: $GC_num, (".int(1000 * $GC_num/$total_ctg_length + 0.5) / 10 ."%)\n";
    print "Total AT count: $AT_num, (".int(1000 * $AT_num/$total_ctg_length + 0.5) / 10 ."%)\n";
    print "Total NX count: $NX_num, (".int(1000 * $NX_num/$total_ctg_length + 0.5) / 10 ."%)\n";
    print "Total: $total_ctg_length\n";
    print "\n";


# if there are fosmids
# this is not needed for newbler assemblies
    if($fosmid_prefix)
    {
	open(R, "> readinfo.txt") or die "cannot create readinfo.txt.\n";
	foreach my $file (@files)
	{
	    next unless ($file =~ /scaffold\d+\.ace/);
	    $file = $dir.$file;
	    if($file =~ /gz$/) {open(F, "zcat $file |") or die "Cannot open $file.\n";}
	    else { open(F, $file) or die "Cannot open $file.\n"; }
	    my $contig;
	    my %read_info = ();
	    while(<F>)
	    {
			chomp($_);
			if ($_ =~ /^CO (\S+) /)
			{
    			$contig = $1;
    			next;
  			}
  			if ($_ =~ /^AF /)
			{ 
    			my @t = split(' ', $_);
    			my $read = $t[1];
    			$read_info{$read}{UorC} = $t[2];
    			$read_info{$read}{StartPos} = $t[3];
    			$read_info{$read}{Ctg} = $contig;
  			}
  			if ($_ =~ /^RD /)
			{
    			my @t = split(' ', $_);
    			my $read = $t[1];
    			$read_info{$read}{Len} = $t[2];
  			}
		}
		# print out contents in this file.
		foreach my $r (sort keys %read_info)
		{
			print R "$r $read_info{$r}{Ctg} $read_info{$r}{UorC} $read_info{$r}{StartPos} $read_info{$r}{Len}\n";
		}
	}
	
	my $used_reads = 0;
	my $cum_len = 0;
	print "\n*** Fosmid Coverage ***\n";
	open(F, "readinfo.txt") or die "cannot open readinfo.txt\n";
	while(<F>)
	{
		next unless ($_ =~ /^$fosmid_prefix/);
		chomp();
		my @a = split(/\s+/, $_);
	
		$used_reads++;
		$cum_len += $a[4];
	}
	print "total fosmids used: $used_reads\n";
	print "total length of these fosmids: $cum_len bp\n";
	my $fos_cov = int(100 * $cum_len * $ave_Q20_bases_per_read /$ave_input_read_length/$total_ctg_length)/100;
	
	print "Estimated fosmid coverage (total fosmids Q20 bases over genome): ", $fos_cov, "X\n";
    }

############################
# CORE GENE SURVEY RESULTS #
############################

    print "\n*** Core Gene survey Result ***\n";
    
    if (-s 'Cov_30_PID_30.out.gz')
    {
	my $fh = IO::File->new("zcat Cov_30_PID_30.out.gz |");
	while (my $line = $fh->getline)
	{
	    print $line if $line =~ /^Perc/;
	    print $line if $line =~ /^Number/;
	    print $line if $line =~ /^Core/;
	}
	$fh->close;
	print "\n";
    }
    else
    {
	print "Cov_30_PID_30.out.gz missing .. unable to create core gene survey results\n\n";
    }
    

###################
# READ DEPTH INFO #
###################

    print "\n*** Read Depth Info ***\n";

    my @aces = glob ("Velvet_ace_for_stats");
    
#print map {$_."\n"} @aces;


    if (scalar @aces > 0)
    {
	my $ace_file = $aces[-1];
	
#    print $ace_file."ace file\n";

	my $depth_out_file = $ace_file.'_base_depths';
	
	if (! -s $depth_out_file)
	{
	    my $depth_fh = IO::File->new(">$depth_out_file");
	    my $ace_fh = IO::File->new("<$ace_file");
	    my $ace_obj = ChimpaceObjects->new ( -acefilehandle => $ace_fh );
	    my %cover_depth;
	    my @contig_names = $ace_obj->get_all_contigNames ();
	    foreach my $contig (@contig_names)
	    {
		print "$contig xx\n";
		my @all_reads = $ace_obj->ReadsInContig ( -contig => $contig );
		
		my $read_count = scalar @all_reads;
		print "read count $read_count\n";
		
		foreach my $read (@all_reads)
		{
		    my $ctg_length = $ace_obj->Contig_Length ( -contig => $contig );
		    
		    next unless $ctg_length > 500;
		    
		    my $align_unpadded_clip_start = $ace_obj->getAlignUnpadedClipStart ( -read => $read );
		    my $align_unpadded_clip_end = $ace_obj->getAlignUnpadedClipEnd ( -read => $read );
		    
		    print "here\n";
		    
		    next if (! defined $align_unpadded_clip_end or ! defined $align_unpadded_clip_start);
		    my $start = $align_unpadded_clip_start - 1;
		    my $end = $align_unpadded_clip_end - 1;
		    
		#if read has a left end overhang, $start value is negative
		#and this causes the array assignment below to crash
		    $start = 0 if $start < 0;
		    
		    for my $i ( $start .. $end )
		    {
			$cover_depth{$contig}[$i]++;
		    }
		}
		my $contig_length = $ace_obj->Contig_Length ( -contig => $contig );
		
		$depth_fh->print (">$contig\n");
		
		for ( my $i = 0; $i < $contig_length; $i++ )
		{
		    $depth_fh->print ("$cover_depth{$contig}[$i] ")
			if defined $cover_depth{$contig}[$i];
		    
		    $depth_fh->print ("\n") if ( ($i % 50) == 49);
		}
	    
		$depth_fh->print ("\n");
		
		delete $cover_depth{$contig};
	    }

	    $ace_fh->close;
	    
	    $depth_fh->close;
	}
	my $total_read_bases = 0;
	my ($one_x_cov, $two_x_cov, $three_x_cov, $four_x_cov, $five_x_cov) = 0;
	my $fh = IO::File->new("<$depth_out_file");
	while (my $line = $fh->getline)
	{
	    next if $line =~ /^>/;
	    next if $line =~ /^\s+$/;
	    chomp $line;
	    my @numbers = split (/\s+/, $line);
	    $total_read_bases += scalar @numbers;
	    foreach my $depth_num (@numbers)
	    {
		$one_x_cov++ if $depth_num >= 1;
		$two_x_cov++ if $depth_num >= 2;
		$three_x_cov++ if $depth_num >= 3;
		$four_x_cov++ if $depth_num >= 4;
		$five_x_cov++ if $depth_num >= 5;
	    }
	}
	$fh->close;

	print "Total consensus bases: $total_read_bases\n".
	    "Depth >= 5: $five_x_cov\t". $five_x_cov/$total_read_bases."\n".
	    "Depth >= 4: $four_x_cov\t". $four_x_cov/$total_read_bases."\n".
	    "Depth >= 3: $three_x_cov\t". $three_x_cov/$total_read_bases."\n".
	    "Depth >= 2: $two_x_cov\t". $two_x_cov/$total_read_bases."\n".
	    "Depth >= 1: $one_x_cov\t". $one_x_cov/$total_read_bases."\n";

    }
    else
    {
	print "Valid ace file not found to create read depth info\n".
	    "Valid ace file should be the latest version of Pcap.454contigs.ace*\n";
    }


#####################
# 5 KB CONTIGS INFO #
#####################


    print "\n\n*** 5 Kb and Greater Contigs Info ***\n";

    if (-s 'contigs.bases')
    {
	my $total_ctg_lengths = 0;
	my $five_kb_ctg_lengths = 0;

	my $fh = IO::File->new("< contigs.bases");
	my $fio = Bio::SeqIO->new(-format => 'fasta', -fh => $fh);
	while (my $f_seq = $fio->next_seq)
	{
	    my $ctg_length = length $f_seq->seq;
	    $total_ctg_lengths += $ctg_length;
	    if ($ctg_length >= 5000)
	    {
		$five_kb_ctg_lengths += $ctg_length;
	    }
	}
	$fh->close;

	my $ratio = 0;
	
	if ($five_kb_ctg_lengths > 0)
	{
	    $ratio = int ($five_kb_ctg_lengths / $total_ctg_lengths * 100);
	}

	print "Total lengths of all contigs: $total_ctg_lengths\n".
	    "Total lengths of contigs 5 Kb and greater: $five_kb_ctg_lengths\n".
	    "Percentage of genome: $ratio%\n";
    }
    else
    {
	print "contigs.bases file missing\n".
	    "unable to determine 5 kb contigs stats\n";
    }
}
