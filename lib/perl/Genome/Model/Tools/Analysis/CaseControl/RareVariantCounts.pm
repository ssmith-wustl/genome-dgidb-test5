
package Genome::Model::Tools::Analysis::CaseControl::RareVariantCounts;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# SearchRuns - Search the database for runs
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	04/01/2009 by D.K.
#	MODIFIED:	04/01/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Analysis::CaseControl::RareVariantCounts {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		vcf_file	=> { is => 'Text', doc => "VCF file with sample genotypes", is_optional => 0, is_input => 1},
		transcript_annotation_file	=> { is => 'Text', doc => "Transcript annotation in native output format", is_optional => 0, is_input => 1},
		vep_annotation_file	=> { is => 'Text', doc => "VEP top annotation file in native output", is_optional => 0, is_input => 1},
		sample_phenotype_file	=> { is => 'Text', doc => "Tab-delimited file with sample ID and phenotype code", is_optional => 0, is_input => 1},
		dbsnp_positions_file	=> { is => 'Text', doc => "1-based positions of dbSNP common SNPs to exclude", is_optional => 1, is_input => 1},
		reference_build	=> { is => 'Text', doc => "reference build -- \"NCBI-human-build36\" or \"GRCh37-lite-build37\"", is_optional => 1, default => 'GRCh37-lite-build37', is_input => 1},
		output_file	=> { is => 'Text', doc => "Output file for analysis results", is_optional => 1, is_input => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Compares the numbers of rare variants in cases versus controls"                 
}

sub help_synopsis {
    return <<EOS
This command compares the number of rare variants in cases versus controls
EXAMPLE:	gmt analysis case-control rare-variant-counts --vcf-file merged.vcf --annotation-file merged.annotation --vep-file merged.vep.input --variant-file all.snvs --consensus-files myCons1,myCons2
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

	my $vcf_file = $self->vcf_file;
	my $sample_phenotype_file = $self->sample_phenotype_file;
	
	if($self->output_file)
	{
		open(OUTFILE, ">" . $self->output_file) or die "Can't open outfile: $!\n";		
		open(OUTGENES, ">" . $self->output_file . ".genes") or die "Can't open outfile: $!\n";
		open(OUTMUTATIONS, ">" . $self->output_file . ".mutations") or die "Can't open outfile: $!\n";
		open(OUTNEUTRAL, ">" . $self->output_file . ".neutral") or die "Can't open outfile: $!\n";
		open(OUTCOUNTS, ">" . $self->output_file . ".counts") or die "Can't open outfile: $!\n";
	}

	my %stats = ();
	
	## Load sample phenotypes ##
	warn "Loading sample phenotypes...\n";
	my %sample_phenotypes = load_sample_phenotypes($sample_phenotype_file);

	my %phenotype_sample_counts = ();
	foreach my $key (keys %sample_phenotypes)
	{
		my $phenotype = $sample_phenotypes{$key};
		$phenotype_sample_counts{$phenotype}++;
	}
	
	print OUTMUTATIONS "chrom\tposition\tref\tvar\tgene\tclass";
	foreach my $phenotype (sort keys %phenotype_sample_counts)
	{
		print OUTMUTATIONS "\t\#$phenotype";
	}
	print OUTMUTATIONS "\n";

	## Load the annotation ##
	warn "Loading transcript annotation...\n";	
	my %transcript_annotation = load_transcript_annotation($self->transcript_annotation_file);

	warn "Loading VEP annotation...\n";
	my %vep_annotation = $self->load_vep_annotation($self->vep_annotation_file);

	## Load dbSNP positions ##
	my %dbsnp_common = ();
	if($self->dbsnp_positions_file)
	{
		warn "Loading dbSNP positions...\n";
		%dbsnp_common = load_dbsnp($self->dbsnp_positions_file);
	}

	## Get the input file ##

	my $input;

#	if(substr($vcf_file, length($vcf_file) - 2, 2) eq 'gz')
#	{
#		$input = `zcat $vcf_file`;		
#	}
#	else
#	{
		$input = new FileHandle ($vcf_file);		
#	}

	warn "Parsing VCF File...\n";

	## PARSE THE VCF FILE ##

	my %samples_in_vcf = ();
	my @sample_names = ();
	my $num_samples = 0;

	my %deleterious_by_gene = ();
	my %rare_variant_counts = ();
	my %rare_allele_counts = ();
	my %samples_with_rare_deleterious = ();	

	my %counted = ();
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
#	if(!$stats{'num_variants'} || $stats{'num_variants'} > 0)	## Always true ##
#	{
		if(substr($line, 0, 1) eq '#')
		{
			if(substr($line, 0, 6) eq '#CHROM')
			{
				## Process the header line ##
				my @lineContents = split(/\t/, $line);
				my $numContents = @lineContents;
				for(my $colCounter = 9; $colCounter < $numContents; $colCounter++)
				{
					my $sample = $lineContents[$colCounter];
					$sample_names[$num_samples] = $sample;
					$num_samples++;
					$samples_in_vcf{$sample} = 1;
				}
				
				warn "$num_samples samples\n";
			}
		}
		elsif($num_samples > 0)
		{
			$stats{'variant'}++;
			## Proceed if we have samples arrayed ##
	
			warn $stats{'variant'} . " variants parsed...\n" if(!($stats{'variant'} % 1000));
	
			## Parse a VCF line ##
	
			## Hash for samples by genotype ##
			my %genotypes_by_sample = ();
			my %samples_by_genotype = my %num_samples_by_genotype = ();
			
			my @lineContents = split(/\t/, $line);
			my $numContents = @lineContents;
	
			my ($chrom, $position, $id, $ref, $alt, $qual, $filter, $info, $format) = split(/\t/, $line);

			## Retrieve transcript and VEP annotation ##
			
			## Get Formatting information ##
			
			my @formatContents = split(/\:/, $format);
			my $numFormats = @formatContents;
			my %format_fields = ();
			for(my $colCounter = 0; $colCounter < $numFormats; $colCounter++)
			{
				my $field = $formatContents[$colCounter];
				$format_fields{$field} = $colCounter;
			}

			## For each variant allele observed ##
			
			my @alt_alleles = split(/\,/, $alt);
			my $alt_index = 0;
			
			foreach my $var (@alt_alleles)
			{
				$alt_index++;
				$stats{'variant_alleles'}++;

				my $variant_key = join("\t", $chrom, $position, $ref, $var);

				if($dbsnp_common{$variant_key})
				{
					$stats{'variant_alleles_excluded_by_dbsnp'}++;
					print OUTNEUTRAL join("\t", $chrom, $position, $ref, $var, "dbSNP", get_annotation_call($transcript_annotation{$variant_key}), get_vep_call($vep_annotation{$variant_key})) . "\n";
				}				
				elsif($transcript_annotation{$variant_key})
				{
					$stats{'variant_alleles_with_transcript'}++;
	
					if($vep_annotation{$variant_key})
					{
						$stats{'variant_alleles_with_vep'}++;
					}
					else
					{
						warn "Variant $variant_key should have VEP\n" if($transcript_annotation{$variant_key} =~ 'missense');
					}
					
					my $deleterious = is_deleterious($transcript_annotation{$variant_key}, $vep_annotation{$variant_key});
					
					## Only proceed if it's deleterious ##
					
					if($deleterious)
					{
						$stats{'variant_alleles_x_deleterious'}++;
						my ($deleterious_gene, $deleterious_type) = split(/\t/, $deleterious);
						$stats{'variant_alleles_x_deleterious_' . $deleterious_type}++;
						$deleterious_by_gene{$deleterious_gene} .= "\n" if($deleterious_by_gene{$deleterious_gene});
						$deleterious_by_gene{$deleterious_gene} .= $deleterious_type;

						my %phenotype_counts = ();
						foreach my $phenotype (keys %phenotype_sample_counts)
						{
							$phenotype_counts{$phenotype} = 0;
						}

						## Get Sample Genotypes ##
						
						my $sampleIndex = 0;
#						$numContents = 0;	## Skip Sample Parsing 
						for(my $colCounter = 9; $colCounter < $numContents; $colCounter++)
						{
							my $sample = $sample_names[$sampleIndex];
							my $entry = $lineContents[$colCounter];
				
							## Only process if we have phenotype for this sample ##
							
							if($sample_phenotypes{$sample})
							{
								my $sample_phenotype = $sample_phenotypes{$sample};
											
								my @entryContents = split(/\:/, $entry);
								my $numEntryContents = @entryContents;
								
								if($numEntryContents >= 3)
								{
									my $genotype = $entryContents[0];
									my $quality = $entryContents[$format_fields{'GQ'}];
									my $depth = $entryContents[$format_fields{'DP'}];
									my $filter = $entryContents[$format_fields{'FT'}];
					
									if(!$filter)
									{
										warn "No filter parsed from $entry field " . $format_fields{'FT'} . "\n";
										exit(0);
									}
					
									if($filter eq '.' || $filter eq 'PASS')
									{
										if($genotype =~ $alt_index)
										{
											$phenotype_counts{$sample_phenotype}++;
											$stats{'x_deleterious_variants_in_samples'}++;
											## Sample has this variant ##
											$rare_variant_counts{$deleterious_gene . "\t" . $sample_phenotype}++;
											
											my ($a1, $a2) = split(/\//, $genotype);
											
											if($a1 eq $a2)
											{
												$rare_allele_counts{$deleterious_gene . "\t" . $sample_phenotype}++;
											}
											else
											{
												$rare_allele_counts{$deleterious_gene . "\t" . $sample_phenotype}++;
											}
											
											if(!$counted{$sample . "\t" . $deleterious_gene})
											{
												$samples_with_rare_deleterious{$deleterious_gene . "\t" . $sample_phenotype}++;
												$counted{$sample . "\t" . $deleterious_gene} = 1;
											}
										}
			
									}					
								}								
							}
				
							$sampleIndex++;
						}
						
						
						print OUTMUTATIONS join("\t", $variant_key, $deleterious);
						foreach my $this_phenotype (sort keys %phenotype_counts)
						{
							$phenotype_counts{$this_phenotype} = 0 if(!$phenotype_counts{$this_phenotype});
							print OUTMUTATIONS "\t$phenotype_counts{$this_phenotype}/$phenotype_sample_counts{$this_phenotype}";
						}
						print OUTMUTATIONS "\n";

					}
					else
					{
						print OUTNEUTRAL join("\t", $chrom, $position, $ref, $var, "notDeleterious", get_annotation_call($transcript_annotation{$variant_key}), get_vep_call($vep_annotation{$variant_key})) . "\n";
					}



				}
				else
				{
					warn "No annotation found for $variant_key\n";
				}
				



			}



	

	
		}
		
#	}
		
	}
	
	close($input);
	
	
#	print $stats{'num_variants'} . " variants\n";

	## Determine how many samples we had overall ##
	my %phenotypes = ();
	foreach my $sample (keys %sample_phenotypes)
	{
		my $phenotype = $sample_phenotypes{$sample};
		$phenotypes{$phenotype}++;
		$stats{'samples_phenotype'}++;
		if($samples_in_vcf{$sample})
		{
			$stats{'samples_vcf_with_phenotype'}++;
			$stats{'samples_vcf_with_phenotype_' . $phenotype}++;
		}
		else
		{
			$stats{'samples_phenotype_no_vcf'}++;
		}
	}
	
	foreach my $sample (keys %samples_in_vcf)
	{
		$stats{'samples_vcf'}++;
		if(!$sample_phenotypes{$sample})
		{
			warn "Sample $sample is in VCF but has no phenotype\n";
			$stats{'samples_vcf_without_phenotype'}++;
		}
	}

	print "SUMMARY\n";
	foreach my $key (sort keys %stats)
	{
		print OUTFILE "$key\t" . $stats{$key} . "\n";
		print $stats{$key} . " $key\n";
	}
	
	## Print deleterious gene list ##

	print "DELETERIOUS BY GENE\n";
	print "gene_symbol\tunique_deleterious_variants\n";
	print OUTGENES "gene_symbol\tunique_deleterious_variants\n";
	my %num_deleterious_by_gene = ();
	foreach my $gene (sort keys %deleterious_by_gene)
	{
		my %category_counts = ();
		
		my @categories = split(/\n/, $deleterious_by_gene{$gene});
		foreach my $category (@categories)
		{
			$num_deleterious_by_gene{$gene}++;
			$category_counts{$category}++;
		}
		
		my $gene_summary = $gene . "\t" . $num_deleterious_by_gene{$gene};
		print "$gene_summary\n";
		
		foreach my $category (sort keys %category_counts)
		{
			$gene_summary .= " $category_counts{$category} $category,";
		}
		
		print OUTGENES "$gene_summary\n";
	}
	
#	print "RARE DELETERIOUS COUNTS\n";
	print OUTCOUNTS "gene\trare_vars";
	foreach my $phenotype (sort keys %phenotypes)
	{
		print OUTCOUNTS "\trare_del_alleles_$phenotype\trare_del_variants_$phenotype\trare_del_samples_$phenotype";
	}
	print OUTCOUNTS "\n";

	foreach my $gene (sort keys %deleterious_by_gene)
	{
		## Print gene and total num deleterious alleles ##
		print OUTCOUNTS join("\t", $gene, $num_deleterious_by_gene{$gene});
		
		foreach my $phenotype (sort keys %phenotypes)
		{
			my $rare_variant_key = join("\t", $gene, $phenotype);

			my $num_rare_alleles = my $num_rare_variants = my $phenotype_portion = 0;
			
			$num_rare_alleles = $rare_allele_counts{$rare_variant_key};
						
			if($rare_variant_counts{$rare_variant_key})
			{
				$num_rare_variants = $rare_variant_counts{$rare_variant_key};
				$phenotype_portion = $num_rare_variants / $stats{'samples_vcf_with_phenotype_' . $phenotype};
#				$phenotype_portion = sprintf("%.3f", ($phenotype_portion * 100)) . '%';				
			}
			
			my $samples_harboring = 0;
			my $portion_samples_harboring = 0;
			
			if($samples_with_rare_deleterious{$rare_variant_key})
			{
				$samples_harboring = $samples_with_rare_deleterious{$rare_variant_key};
				$portion_samples_harboring = $samples_harboring / $stats{'samples_vcf_with_phenotype_' . $phenotype};
#				$portion_samples_harboring = sprintf("%.3f", $portion_samples_harboring * 100) . '%';
			}
			
			print OUTCOUNTS "\t" . join("\t", $num_rare_alleles, $num_rare_variants, $samples_harboring);
#			print OUTCOUNTS "\t" . join("\t", $num_rare_variants, $phenotype_portion);
		}

		print OUTCOUNTS "\n";
	}

	if($self->output_file)
	{
		close(OUTFILE);
		close(OUTGENES);
		close(OUTCOUNTS);
		close(OUTMUTATIONS);
		close(OUTNEUTRAL);
	}

	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}




################################################################################################
# Is_deleterious
#
################################################################################################

sub get_annotation_call
{
	my $transcript_annotation = shift(@_);

	my $call = "-\t-";
	
	if($transcript_annotation)
	{
		my @transcriptContents = split(/\t/, $transcript_annotation);
		my $gene_name = $transcriptContents[6];
		my $trv_type = $transcriptContents[13];
		$call = "$gene_name\t$trv_type";		
	}

	return($call);
}


################################################################################################
# Is_deleterious
#
################################################################################################

sub get_vep_call
{
	my $vep_annotation = shift(@_);

	my $vep_class = my $vep_gene = "-";
	
	if($vep_annotation)
	{
		my @vepContents = split(/\t/, $vep_annotation);
		$vep_class = $vepContents[6];
		my $extra = $vepContents[13];

		if($extra)
		{
	
			## Parse out gene symbol, sift, polyphen, condel ##
			my $polyphen = my $sift = my $condel = "";
	
			my @extraContents = split(/\;/, $extra);
			foreach my $entry (@extraContents)
			{
				my ($key, $value) = split(/\=/, $entry);
	
				$vep_gene = $value if($key eq 'HGNC');
				$polyphen = $value if($key eq 'PolyPhen');
				$sift = $value if($key eq 'SIFT');
				$condel = $value if($key eq 'Condel');

			}

			if($polyphen && $sift && $condel)
			{
				$vep_class .= ":" . $polyphen . ":" . $sift . ":" . $condel;
			}
		}
	}

	return($vep_gene . "\t" . $vep_class);
}

################################################################################################
# Is_deleterious
#
################################################################################################

sub is_deleterious
{
	my ($transcript_annotation, $vep_annotation) = @_;

	my @transcriptContents = split(/\t/, $transcript_annotation);
	my $gene_name = $transcriptContents[6];
	my $trv_type = $transcriptContents[13];
	
	if($trv_type eq 'nonsense' || $trv_type eq 'nonstop' || $trv_type eq 'splice_site' || $trv_type eq 'frame_shift_del' || $trv_type eq 'frame_shift_ins' || $trv_type eq 'splice_site_del' || $trv_type eq 'splice_site_ins')
	{
		return($gene_name . "\t" . $trv_type);
	}
	
	if($vep_annotation)
	{
		my @vepContents = split(/\t/, $vep_annotation);

#		my ($chrom, $position, $alleles) = split(/\_/, $vepContents[0]);
#		my ($ref, $var) = split(/\//, $alleles);
#		my $key = join("\t", $chrom, $position, $alleles);
		my $ens_gene = $vepContents[3];
		my $vep_class = $vepContents[6];
		my $cdna_pos = $vepContents[7];
		my $cds_pos = $vepContents[8];
		my $protein_pos = $vepContents[9];
		my $amino_acids = $vepContents[10];
		my $extra = $vepContents[13];

		my $gene = "";

		## Break VEP classes into array since these allow multiples ##
		my %vep_class = ();
		my $damaging_vep_types = "";
		my $damaging_calls = "";
		if($vep_class)
		{
			my @vep_class = split(/\,/, $vep_class);
			foreach my $class (@vep_class)
			{
				$vep_class{$class} = 1;
				
				if($class =~ 'NON_SYN')
				{
					$damaging_vep_types .= "," if($damaging_vep_types);
					$damaging_vep_types .= 'NON_SYN';
				}
				elsif($class =~ 'ESSENTIAL_SPLICE' || $class =~ 'STOP')
				{
					$damaging_vep_types .= "," if($damaging_vep_types);
					$damaging_vep_types .= $class;
				}
			}			
		}
	
		
		if($extra)
		{
	
			## Parse out gene symbol, sift, polyphen, condel ##
			my $polyphen = my $sift = my $condel = "";
	
			my @extraContents = split(/\;/, $extra);
			foreach my $entry (@extraContents)
			{
				my ($key, $value) = split(/\=/, $entry);
	
				$gene = $value if($key eq 'HGNC');
				$polyphen = $value if($key eq 'PolyPhen');
				$sift = $value if($key eq 'SIFT');
				$condel = $value if($key eq 'Condel');	
			}
			
			if($gene)
			{
				if(($polyphen =~ 'damaging' || $sift =~ 'deleterious' || $condel =~ 'deleterious')) #$vep_class{'NON_SYNONYMOUS_CODING'} && 
				{
					
					$damaging_calls = "Polyphen" if($polyphen =~ 'damaging');
					
					if($sift =~ 'deleterious')
					{
						$damaging_calls .= "/" if($damaging_calls);
						$damaging_calls .= "SIFT";					
					}
	
					if($condel =~ 'deleterious')
					{
						$damaging_calls .= "/" if($damaging_calls);
						$damaging_calls .= "Condel";					
					}
					
					return($gene . "\t" . $damaging_vep_types . ":" . $damaging_calls);
				}
			}			
		}
		
		if($damaging_vep_types)
		{
			return($gene . "\t" . $damaging_vep_types . ":" . $damaging_calls);
		}

	}
	
	return(0);
}


################################################################################################
# Load Genotypes
#
################################################################################################

sub load_sample_phenotypes
{                               # replace with real execution logic.
	my $input_file = shift(@_);
	my %phenotypes = ();
	
	my $input = new FileHandle ($input_file);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		my ($sample_name, $phenotype) = split(/\t/, $line);
		$phenotypes{$sample_name} = $phenotype;
	}
	close($input);
                            # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)

	return(%phenotypes);
}



################################################################################################
# Load Genotypes
#
################################################################################################

sub load_transcript_annotation
{                               # replace with real execution logic.
	my $input_file = shift(@_);
	my %annotation = ();
	
	my $input = new FileHandle ($input_file);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		my ($chrom, $chr_start, $chr_stop, $ref, $var) = split(/\t/, $line);
		my $key = join("\t", $chrom, $chr_start, $ref, $var);
		$annotation{$key} = $line;
	}
	close($input);
                            # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)

	return(%annotation);
}


################################################################################################
# Load Genotypes
#
################################################################################################

sub load_vep_annotation {
	my $self = shift;
	my $FileName = shift;
	my $reference_build = $self->reference_build;

	my %results = ();

	my $input = new FileHandle ($FileName);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	
		if(substr($line, 0, 1) eq '#') {
			## Ignore header line ##
		}
		else {
			my @lineContents = split(/\t/, $line);
			my ($chrom, $position, $alleles, $ref, $var);
            if ($lineContents[0] =~ m/rs/) {
                ($chrom, $position) = split(/:/,$lineContents[1]);
                $var = $lineContents[2];
                my $reference_build_fasta_object = Genome::Model::Build::ReferenceSequence->get(name => "$reference_build");
                my $reference_build_fasta = $reference_build_fasta_object->data_directory . "/all_sequences.fa";
                $ref = `samtools faidx $reference_build_fasta $chrom:$position-$position | grep -v ">"`;
                chomp($ref);
            }
            else {
    			($chrom, $position, $alleles) = split(/\_/, $lineContents[0]);
    			($ref, $var) = split(/\//, $alleles);
            }
			my $key = join("\t", $chrom, $position, $ref, $var);
			$results{$key} = $line;
		}
		
#		return(%results) if($lineCounter > 1000);
	}
	
	close($input);
	
	return(%results);
}



################################################################################################
# Load Genotypes
#
################################################################################################

sub load_dbsnp
{                               # replace with real execution logic.
	my $input_file = shift(@_);
	my %dbsnp = ();
	
	my $input = new FileHandle ($input_file);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		my ($chrom, $chr_start, $chr_stop, $ref, $var) = split(/\t/, $line);
		my $key = join("\t", $chrom, $chr_start, $ref, $var);
		
		$dbsnp{$key} = 1;
	}
	close($input);
                            # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)

	return(%dbsnp);
}


sub commify
{
	local($_) = shift;
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}


1;


