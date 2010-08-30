
package Genome::Model::Tools::Analysis::Maf::Proximity;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# Proximity - Perform a proximity analysis on mutations in the MAF file.
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	08/24/2010 by D.K.
#	MODIFIED:	08/24/2010 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

my $max_proximity = 10;

class Genome::Model::Tools::Analysis::Maf::Proximity {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		maf_file	=> { is => 'Text', doc => "Original MAF file" },
		output_file	=> { is => 'Text', doc => "Output file for proximity report", is_optional => 1 },
		output_maf	=> { is => 'Text', doc => "MAF file with appended item", is_optional => 1 },		
		max_proximity	=> { is => 'Text', doc => "Maximum aa distance between mutations [10]", is_optional => 1 },
		verbose		=> { is => 'Text', doc => "Print verbose output", is_optional => 1 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Performs a proximity analysis on mutations in a MAF file"                 
}

sub help_synopsis {
    return <<EOS
This command performs a proximity analysis on mutations in a MAF file
EXAMPLE:	gt analysis maf proximity --maf-file original.maf --output-file proximity-genes.tsv
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 

EOS
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
	my $self = shift;

	## Get required parameters ##
	my $maf_file = $self->maf_file;
	$max_proximity = $self->max_proximity if(defined($self->max_proximity));

	if(!(-e $maf_file))
	{
		die "Error: MAF file 1 not found!\n";
	}

	if($self->output_file)
	{
		open(OUTFILE, ">" . $self->output_file) or die "Can't open outfile: $!\n";
	}
	

	my %stats = ();

	## Column index for fields in MAF file ##
	
	my %column_index = ();
	my @columns = ();

	my %nonsilent_mutations = ();
	my %mutated_aa_positions = ();

	## Parse the MAF file ##
	
	my $input = new FileHandle ($maf_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		

		my @lineContents = split(/\t/, $line);
	
		if($lineCounter <= 2 && $line =~ "Chrom")
		{
		
			my $numContents = @lineContents;
			
			for(my $colCounter = 0; $colCounter < $numContents; $colCounter++)
			{
				if($lineContents[$colCounter])
				{
					$column_index{$lineContents[$colCounter]} = $colCounter;
				}
			}
			
			foreach my $column (keys %column_index)
			{
				## Print out the columns as parsed ##
				#print "$column_index{$column}\t$column\n";
				$columns[$column_index{$column}] = $column;	## Save the column order ##
			}
		}
		elsif($lineCounter < 2)
		{

		}
		elsif($lineCounter > 2 && !@columns)
		{
			die "No Header in MAF file!\n";
		}
		elsif($lineCounter > 2 && @columns)
		{
			## Build a record for this line, assigning all values to respective fields ##
			
			my %record = ();

			foreach my $column_name (keys %column_index)
			{
				my $column_number = $column_index{$column_name};
				$record{$column_name} = $lineContents[$column_number];
			}			


			## Here's how to parse out information for this record ##
			
			my $hugo_name = $record{'Hugo_Symbol'};
			my $tumor_sample = $record{'Tumor_Sample_Barcode'};


			## Parse the gene name ##
			my $chrom = $record{'chromosome_name'};
			my $chr_start = $record{'start'};
			my $chr_stop = $record{'stop'};
			my $ref_allele = $record{'reference'};
			my $var_allele = $record{'variant'};
			
			my $gene = $record{'gene_name'};
			my $trv_type = $record{'trv_type'};
			my $c_position = $record{'c_position'};
			my $aa_change = $record{'amino_acid_change'};

			$c_position =~ s/c\.// if($c_position);
			$aa_change =~ s/p\.// if($aa_change);

			my $aa_position = 0;
			my $tx_start = my $tx_stop = 0;
			my $aa_position_start = my $aa_position_stop = 0;
			my $inferred_aa_start = my $inferred_aa_stop = 0;
			my $aa_pos = my $inferred_aa_pos = 0;


			## Proceed with non-silent mutations ##

			if($trv_type ne "silent" && $trv_type ne "rna")
			{
#				print "$gene\t$trv_type\t$c_position\t$aa_change\n";
#				exit(0);

				## Parse out aa_change if applicable and not a splice site ##
				if($aa_change && $aa_change ne "NULL" && substr($aa_change, 0, 1) ne "e")
				{
					$aa_pos = $aa_change;
					$aa_pos =~ s/[^0-9]//g;
				}
				
				## Parse out c_position if applicable ##
				
				if($c_position && $c_position ne "NULL")
				{
					## If multiple results, parse both ##
					
					if($c_position =~ '_')
					{
						($tx_start, $tx_stop) = split(/\_/, $c_position);
						$tx_start =~ s/[^0-9]//g;
						$tx_stop =~ s/[^0-9]//g;
						
						if($tx_stop < $tx_start)
						{
							$inferred_aa_start = $tx_stop / 3;
							$inferred_aa_start = sprintf("%d", $inferred_aa_start) + 1 if($tx_stop % 3);
							$inferred_aa_stop = $tx_start / 3;
							$inferred_aa_stop = sprintf("%d", $inferred_aa_stop) + 1 if($tx_start % 3);							
						}
						else
						{
							$inferred_aa_start = $tx_start / 3;
							$inferred_aa_start = sprintf("%d", $inferred_aa_start) + 1 if($tx_start % 3);
							$inferred_aa_stop = $tx_stop / 3;							
							$inferred_aa_stop = sprintf("%d", $inferred_aa_stop) + 1 if($tx_stop % 3);
						}

					}
					else
					{
						(my $tx_pos) = split(/[\+\-\_]/, $c_position);
						$tx_pos =~ s/[^0-9]//g;

						$tx_start = $tx_stop = $tx_pos;

						if($tx_pos)
						{
							$inferred_aa_pos = $tx_pos / 3;
							$inferred_aa_pos = sprintf("%d", $inferred_aa_pos) + 1 if($tx_pos % 3);
							$inferred_aa_start = $inferred_aa_stop = $inferred_aa_pos;
						}
						else
						{
							warn "Unable to parse tx pos from $c_position\n";
						}						
					}

				}
	
	
				## If we inferred aa start stop, proceed with it ##
				
				if($inferred_aa_start && $inferred_aa_stop)
				{
					$aa_position_start = $inferred_aa_start;
					$aa_position_stop = $inferred_aa_stop;
					
					## IF we also had an aa_position reported in the aa_change column, compare them ##
					
					if($aa_pos && $aa_pos ne $inferred_aa_start && $aa_pos ne $inferred_aa_stop)
					{
#						warn "From $c_position inferred $inferred_aa_start-$inferred_aa_stop but from $aa_change got $aa_pos\n";

						my $diff1 = abs($inferred_aa_start - $aa_pos);
						my $diff2 = abs($inferred_aa_stop - $aa_pos);

						## If it's an SNV, we'll trust the reported aa_position##

						if($tx_start == $tx_stop)
						{
							$aa_position_start = $aa_pos;
							$aa_position_stop = $aa_pos;							
						}

						## Characterize the differences ##
						
						if($diff1 <= 2 || $diff2 <= 2)
						{
							$stats{'aa_pos_close'}++;
						}
						elsif($aa_change =~ 'fs' || $aa_change =~ 'frame')
						{
							## Indel diff so ignore ##
							$stats{'aa_pos_diff_but_indel'}++;
						}
						else
						{
							$stats{'aa_pos_diff'}++;
						}

					}
					else
					{
						$stats{'aa_pos_match'}++;
					}
					
					$stats{'aa_position_inferred'}++;
				}
				## Otherwise if we inferred aa position ##
				elsif($aa_pos)
				{
					$aa_position_start = $aa_pos;
					$aa_position_stop = $aa_pos;
					$stats{'aa_position_only'}++;
				}
				## Otherwise we were unable to infer the info ##
				else
				{
					$stats{'aa_position_not_found'}++;
					#warn "Miss on $chrom\t$chr_start\t$chr_stop\t$ref_allele\t$var_allele\t$gene\t$c_position\t$aa_change\t$aa_pos\t$inferred_aa_pos\n";					
				}
				
				
				## Proceed if we have aa_position_start and stop ##
				
				if($aa_position_start && $aa_position_stop)
				{
					## Save the mutation ##
					
					my $mutation_key = join("\t", $chrom, $chr_start, $chr_stop, $ref_allele, $var_allele);
					my $gene_key = join("\t", $gene, $aa_position_start, $aa_position_stop, $tumor_sample);
					$nonsilent_mutations{$gene_key} = $mutation_key;

					## Case 1, same start and stop (SNV or small indel)
					
					if($aa_position_start == $aa_position_stop)
					{
						## Append to gene list of mutations ##
						$mutated_aa_positions{$gene} .= "\n" if($mutated_aa_positions{$gene});
						$mutated_aa_positions{$gene} .= "$aa_position_start\t$aa_position_stop\t$tumor_sample";
					}
					## Case 2, different start and stop ##
					else
					{
						## Append start and stop gene list of mutations ##
						$mutated_aa_positions{$gene} .= "\n" if($mutated_aa_positions{$gene});
						$mutated_aa_positions{$gene} .= "$aa_position_start\t$aa_position_stop\t$tumor_sample";
					}
				}


			}

		}

	}

	close($input);	
	

	print $stats{'aa_position_inferred'} . " positions were inferred\n";
	print $stats{'aa_pos_match'} . " AA positions matched\n";
	print $stats{'aa_pos_close'} . " AA positions were close\n";
	print $stats{'aa_pos_diff_but_indel'} . " AA positions were off but indels, so tx-inference trusted\n";
	print $stats{'aa_pos_diff'} . " AA positions were way off\n" if($stats{'aa_pos_diff'});
	print $stats{'aa_position_only'} . " were notated but couldn't be inferred\n" if($stats{'aa_position_only'});
	print $stats{'aa_position_not_found'} . " positions couldn't be parsed due to missing info\n";


	## Iterate through gene list and perform proximity analysis ##


	## Print header to output file ##
	
	if($self->output_file)
	{
		## Print a header ##
		
		print OUTFILE "gene\ttotal\tproxim";

		for(my $aa_distance = 0; $aa_distance <= $max_proximity; $aa_distance++)
		{
			print OUTFILE "\td=$aa_distance";
		}

		print OUTFILE "\n";
		
	}

	## Print a header ##
	
	print "gene\ttotal\tproxim";
	for(my $aa_distance = 0; $aa_distance <= $max_proximity; $aa_distance++)
	{
		print "\td=$aa_distance";
	}
	print "\n";

	## Save all mutations in cluster for later output ##
	
	my %mutations_in_cluster = ();

	foreach my $gene (sort keys %mutated_aa_positions)
	{
		$stats{'genes_with_mutations'}++;
		
#		if($gene eq "BRCA1" || $gene eq "BRCA2")# || $gene eq "TP53")
#		{
			my %gene_stats = ();
			$gene_stats{'total_mutations'} = $gene_stats{'proximal_mutations'} = 0;
			
			if($self->verbose)
			{
				print "$gene\n";
				
				print "MUTATION LIST\n";
#				print "$mutated_aa_positions{$gene}\n";

			}
			
			my @mutations = split(/\n/, $mutated_aa_positions{$gene});
			my %mutated_positions = load_aa_positions($mutated_aa_positions{$gene});
			
			foreach my $mutation (@mutations)
			{
				$gene_stats{'total_mutations'}++;
#				print "RUNNING mutation # " . $gene_stats{'total_mutations'} . "\n";

				my ($aa_start, $aa_stop, $sample_name) = split(/\t/, $mutation);
				my $sample_mutation_key = join("\t", $gene, $aa_start, $aa_stop, $sample_name);
				
				## Find the minimum aa distance to another mutation ##
				my $this_mutation_is_done = 0;
				my $this_mutation_min_aa_distance = $max_proximity + 1;
				my $aa_distance = 0;
				
				while($aa_distance <= $max_proximity && !$this_mutation_is_done)
				{
					## Check upstream ##
					
					my $check_aa_pos = $aa_start - $aa_distance;
					
					if($mutated_positions{$check_aa_pos} && different_sample($sample_name, $mutated_positions{$check_aa_pos}))
					{
						## Found a variant upstream, so this mutation is done ##
						$this_mutation_min_aa_distance = $aa_distance;
						$this_mutation_is_done = 1;
					}
					else
					{
						## Search for variant downstream ##
						my $check_aa_pos = $aa_stop + $aa_distance;
						if($mutated_positions{$check_aa_pos} && different_sample($sample_name, $mutated_positions{$check_aa_pos}))
						{
							## Found a variant upstream, so this mutation is done ##
							$this_mutation_min_aa_distance = $aa_distance;
							$this_mutation_is_done = 1;
						}
					}
					
					$aa_distance++;
				}
				
				if($this_mutation_min_aa_distance <= $max_proximity)
				{
					$mutations_in_cluster{$sample_mutation_key} = 1;
					$gene_stats{'proximal_mutations'}++;
					
					$gene_stats{'within ' . $this_mutation_min_aa_distance}++;
				}
				
				print "$mutation\t$this_mutation_min_aa_distance\n" if($self->verbose);
				
				
			}

			print "END LIST\n" if($self->verbose);

			##Print the summary for the gene ##
			
			## PROCEED IF WE HAVE ANY PROXIMAL MUTATIONS ##
			
			if($gene_stats{'proximal_mutations'} > 0)
			{
				$stats{'genes_with_clusters'}++;
				## Build a gene summary ##
				
				my $gene_summary = join("\t", $gene, $gene_stats{'total_mutations'}, $gene_stats{'proximal_mutations'});
				
				for(my $aa_distance = 0; $aa_distance <= $max_proximity; $aa_distance++)
				{
					my $stats_key = "within $aa_distance";
					my $proximity_count = 0;
					$proximity_count = $gene_stats{$stats_key} if($gene_stats{$stats_key});
					$gene_summary .= "\t" . $proximity_count;
				}
				
				print "$gene_summary\n";
	
				if($self->output_file)
				{
					print OUTFILE "$gene_summary\n";
				}
			}


#		}
	}


	print $stats{'genes_with_mutations'} . " genes with at least one mutation\n";
	print $stats{'genes_with_clusters'} . " genes with mutation clusters\n";


	if($self->output_maf)
	{
		open(OUTMAF, ">" . $self->output_maf) or die "Can't open outfile: $!\n";



		## Re-parse the MAF file ##
		
		my $input = new FileHandle ($maf_file);
		my $lineCounter = 0;
		
		while (<$input>)
		{
			chomp;
			my $line = $_;
			$lineCounter++;		
	
			my @lineContents = split(/\t/, $line);
		
			if($lineCounter == 1)
			{
				print OUTMAF "$line\n";				
			}
			elsif($lineCounter <= 2 && $line =~ "Chrom")
			{
				print OUTMAF "$line\twith_aa_pos\tin_" . $max_proximity . "_cluster\n";
			}
			elsif(@columns)
			{
				## Build a record for this line, assigning all values to respective fields ##
				
				my %record = ();
	
				foreach my $column_name (keys %column_index)
				{
					my $column_number = $column_index{$column_name};
					$record{$column_name} = $lineContents[$column_number];
				}			
	
				my $tumor_sample = $record{'Tumor_Sample_Barcode'};
				my $gene = $record{'gene_name'};
				my $trv_type = $record{'trv_type'};
				my $c_position = $record{'c_position'};
				my $aa_change = $record{'amino_acid_change'};
	
				$c_position =~ s/c\.// if($c_position);
				$aa_change =~ s/p\.// if($aa_change);
	
				my $aa_position = 0;
				my $tx_start = my $tx_stop = 0;
				my $aa_position_start = my $aa_position_stop = 0;
				my $inferred_aa_start = my $inferred_aa_stop = 0;
				my $aa_pos = my $inferred_aa_pos = 0;
	
				my $flag_aa_included = 0;
				my $flag_as_cluster = 0;
				
				## Proceed with non-silent mutations ##
	
				if($trv_type && $trv_type ne "silent" && $trv_type ne "rna")
				{
	#				print "$gene\t$trv_type\t$c_position\t$aa_change\n";
	#				exit(0);
	
					## Parse out aa_change if applicable and not a splice site ##
					if($aa_change && $aa_change ne "NULL" && substr($aa_change, 0, 1) ne "e")
					{
						$aa_pos = $aa_change;
						$aa_pos =~ s/[^0-9]//g;
					}
					
					## Parse out c_position if applicable ##
					
					if($c_position && $c_position ne "NULL")
					{
						## If multiple results, parse both ##
						
						if($c_position =~ '_')
						{
							($tx_start, $tx_stop) = split(/\_/, $c_position);
							$tx_start =~ s/[^0-9]//g;
							$tx_stop =~ s/[^0-9]//g;
							
							if($tx_stop < $tx_start)
							{
								$inferred_aa_start = $tx_stop / 3;
								$inferred_aa_start = sprintf("%d", $inferred_aa_start) + 1 if($tx_stop % 3);
								$inferred_aa_stop = $tx_start / 3;
								$inferred_aa_stop = sprintf("%d", $inferred_aa_stop) + 1 if($tx_start % 3);							
							}
							else
							{
								$inferred_aa_start = $tx_start / 3;
								$inferred_aa_start = sprintf("%d", $inferred_aa_start) + 1 if($tx_start % 3);
								$inferred_aa_stop = $tx_stop / 3;							
								$inferred_aa_stop = sprintf("%d", $inferred_aa_stop) + 1 if($tx_stop % 3);
							}
	
						}
						else
						{
							(my $tx_pos) = split(/[\+\-\_]/, $c_position);
							$tx_pos =~ s/[^0-9]//g;
	
							$tx_start = $tx_stop = $tx_pos;
	
							if($tx_pos)
							{
								$inferred_aa_pos = $tx_pos / 3;
								$inferred_aa_pos = sprintf("%d", $inferred_aa_pos) + 1 if($tx_pos % 3);
								$inferred_aa_start = $inferred_aa_stop = $inferred_aa_pos;
							}
							else
							{
								warn "Unable to parse tx pos from $c_position\n";
							}						
						}
	
					}
		
		
					## If we inferred aa start stop, proceed with it ##
					
					if($inferred_aa_start && $inferred_aa_stop)
					{
						$aa_position_start = $inferred_aa_start;
						$aa_position_stop = $inferred_aa_stop;
						$flag_aa_included = 1;
						
						## IF we also had an aa_position reported in the aa_change column, compare them ##
						
						if($aa_pos && $aa_pos ne $inferred_aa_start && $aa_pos ne $inferred_aa_stop)
						{
	#						warn "From $c_position inferred $inferred_aa_start-$inferred_aa_stop but from $aa_change got $aa_pos\n";
	
							my $diff1 = abs($inferred_aa_start - $aa_pos);
							my $diff2 = abs($inferred_aa_stop - $aa_pos);
	
							## If it's an SNV, we'll trust the reported aa_position##
	
							if($tx_start == $tx_stop)
							{
								$aa_position_start = $aa_pos;
								$aa_position_stop = $aa_pos;							
							}
	
							## Characterize the differences ##
							
							if($diff1 <= 2 || $diff2 <= 2)
							{
								$stats{'aa_pos_close'}++;
							}
							elsif($aa_change =~ 'fs' || $aa_change =~ 'frame')
							{
								## Indel diff so ignore ##
								$stats{'aa_pos_diff_but_indel'}++;
							}
							else
							{
								$stats{'aa_pos_diff'}++;
							}
	
						}
						else
						{
							$stats{'aa_pos_match'}++;
						}
						
						$stats{'aa_position_inferred'}++;
					}
					## Otherwise if we inferred aa position ##
					elsif($aa_pos)
					{
						$aa_position_start = $aa_pos;
						$aa_position_stop = $aa_pos;
						$stats{'aa_position_only'}++;
					}
					## Otherwise we were unable to infer the info ##
					else
					{
						$stats{'aa_position_not_found'}++;
						#warn "Miss on $chrom\t$chr_start\t$chr_stop\t$ref_allele\t$var_allele\t$gene\t$c_position\t$aa_change\t$aa_pos\t$inferred_aa_pos\n";					
					}
					
					
					## Proceed if we have aa_position_start and stop ##
					
					if($aa_position_start && $aa_position_stop)
					{
						## Save the mutation ##
						
						my $gene_key = join("\t", $gene, $aa_position_start, $aa_position_stop, $tumor_sample);

						if($mutations_in_cluster{$gene_key})
						{
							$flag_as_cluster = 1;
						}
	

					}
	
	
				}
				
				if(substr($line, length($line) - 1, 1) eq "\t")
				{
					print OUTMAF "$line$flag_aa_included\t$flag_as_cluster\n";					
				}
				else
				{
					print OUTMAF "$line\t$flag_aa_included\t$flag_as_cluster\n";					
				}

	
			}
	
		}
	
		close($input);			
	}


	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}




################################################################################################
# Execute - the main program logic
#
################################################################################################

sub load_aa_positions
{
	my $mutation_list = shift(@_);
	my %aa_positions = ();
	my @mutations = split(/\n/, $mutation_list);

	foreach my $mutation (@mutations)
	{
		my ($aa_start, $aa_stop, $sample) = split(/\t/, $mutation);
		
		## Save the aa_start ##
		
		my $key = $aa_start;

		## Append this sample to the list if needed ##
		
		if($aa_positions{$key})
		{
			$aa_positions{$key} .= "\n$sample";
		}
		else
		{
			$aa_positions{$key} = "$sample";
		}
		
		## If the stop position differs, do the same here ##

		if($aa_start != $aa_stop)
		{
			my $key = $aa_stop;
	
			## Append this sample to the list if needed ##
			
			if($aa_positions{$key})
			{
				$aa_positions{$key} .= "\n$sample";
			}
			else
			{
				$aa_positions{$key} = "$sample";
			}			
		}
	}
	
	return(%aa_positions);
}



################################################################################################
# Execute - the main program logic
#
################################################################################################

sub different_sample
{
	(my $sample_name, my $sample_list) = @_;
	
	my @sample_list = split(/\n/, $sample_list);
	
	foreach my $check_sample (@sample_list)
	{
		if($check_sample ne $sample_name)
		{
			## We have a different sample so return 1 ##
			return(1);
		}
	}

	return(0);
}



1;

