
package Genome::Model::Tools::Capture::GermlineMafStatistics;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# GermlineMafStatistics - Take Maf File and Generate Standard Statistics
#					
#	AUTHOR:		Will Schierding (wschierd@genome.wustl.edu)
#
#	CREATED:	02/28/2011 by W.S.
#	MODIFIED:	02/28/2011 by W.S.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it
use POSIX;

## Declare global statistics hash ##

my %stats = ();
my %stats2 = ();

class Genome::Model::Tools::Capture::GermlineMafStatistics {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		maf_file	=> { is => 'Text', doc => "Maf File To Read (or space separated list of Maf files to merge then read" , is_optional => 0},
		regions_file	=> { is => 'Text', doc => "Regions File -- Used to Get Targeted Region Basic Stats" , is_optional => 1},
		output_file	=> { is => 'Text', doc => "Output File With Statistics" , is_optional => 0},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Take Maf File and Generate Standard Statistics -- for GERMLINE projects"                 
}

sub help_synopsis {
    return <<EOS
Generate MAF File, Get dbsnp output, and strandfilter -- for GERMLINE events
EXAMPLE:	gmt capture germline-maf-statistics
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

	my $output_file = $self->output_file;
	my $maf_list = $self->maf_file;

#	my %model_hash;
#	my $model_input = new FileHandle ($model_list_file);
#	while (my $line = <$model_input>) {
#		chomp($line);
#		$line =~ s/\s+/\t/g;
#		my ($model_id, $sample_name, $build_id, $build_status, $builddir) = split(/\t/, $line);
#		$model_hash{$sample_name} = "$model_id\t$build_id\t$builddir";
#	}
#	my $model_count = 0;
#	foreach (sort keys %model_hash) {
#		$model_count++;
#	}
#	print "Model List Loaded, $model_count Models in List\n";

	## Open the outfile ##
	open(OUTFILE, ">$output_file") or die "Can't open output file: $!\n";

	my %variant_status;
	my @maffiles = split(/\s/, $maf_list);
	my %variants;
	foreach my $maf_file (@maffiles) {
		my %samples;
		my $input = new FileHandle ($maf_file);
		my $header = <$input>;
		while (my $line = <$input>) {
			chomp($line);
			my ($gene_name,$gene_id,$center,$ref_build,$chromosome,$chr_start,$chr_stop,$strand,$mutation_type,$variant_type,$ref,$tumor_gt_allele1,$tumor_gt_allele2,$dbsnp_rs,$dbsnp_status,$sample_name,$sample_name2,$ref2,$ref3,$val1,$val2,$val3,$val4,$strandfilter_status,$val_status,$mut_status,$val_method,$sequence_phase,$sequence_source,$score,$bam_file,$sequencer, @annotation) = split(/\t/, $line);
			$samples{$sample_name}++;
			$stats{'TotalVariants'}++;
			$stats{$strandfilter_status}{$variant_type}++;
			$stats{$strandfilter_status}{'total'}++;
			my $variant = "$chromosome\t$chr_start\t$chr_stop\t$ref\t$tumor_gt_allele2";
			my $variant_pos = "$chromosome\t$chr_start\t$chr_stop";
			if ($dbsnp_rs =~ m/novel/i) {
				my $dbsnp = 'novel';
				$stats{$dbsnp}++;
				$stats{$strandfilter_status}{$dbsnp}++;
				$stats2{$strandfilter_status}{$dbsnp}{$variant_type}++;
				$variant_status{$variant_type}++;
				$variants{$strandfilter_status}{$dbsnp}{'variant'}{$variant}++;
				$variants{$strandfilter_status}{$dbsnp}{'position'}{$variant_pos}++;

			}
			else {
				my $dbsnp = 'dbsnp';
				$stats{$dbsnp}++;
				$stats{$strandfilter_status}{$dbsnp}++;
				$stats2{$strandfilter_status}{$dbsnp}{$variant_type}++;
				$variant_status{$variant_type}++;
				$variants{$strandfilter_status}{$dbsnp}{'variant'}{$variant}++;
				$variants{$strandfilter_status}{$dbsnp}{'position'}{$variant_pos}++;

			}
	
		}
		foreach my $sample_name (sort keys %samples) {
			$stats{'samples'}++;
		}

	}

#	print OUTFILE Data::Dumper::Dumper(%variants);
#	my @blah = (sort keys %variants);
#	print "@blah\n";
my $sum = 0;
my $sum2 = 0;
	foreach my $strandfilter_status (sort keys %variants) {
		foreach my $dbsnp (sort keys %{$variants{$strandfilter_status}}) {
			foreach my $variant (sort keys %{$variants{$strandfilter_status}{$dbsnp}{'variant'}}) {
				if (defined($variants{$strandfilter_status}{$dbsnp}{'variant'}{$variant}) && $variants{$strandfilter_status}{$dbsnp}{'variant'}{$variant} == 1) {
					$stats2{$strandfilter_status}{$dbsnp}{'singletons'}++;
#					print OUTFILE "$variant\n";
					$sum += $variants{$strandfilter_status}{$dbsnp}{'variant'}{$variant};
				}
				elsif (defined($variants{$strandfilter_status}{$dbsnp}{'variant'}{$variant}) && $variants{$strandfilter_status}{$dbsnp}{'variant'}{$variant} > 1) {
					$stats2{$strandfilter_status}{$dbsnp}{'nonsingletons'}++;
#					print OUTFILE "$variant\n";
					$sum2 += $variants{$strandfilter_status}{$dbsnp}{'variant'}{$variant};
				}
			}
			foreach my $variant (sort keys %{$variants{$strandfilter_status}{$dbsnp}{'position'}}) {
				$stats2{$strandfilter_status}{$dbsnp}{'TotalVariantsSNV'}++;
			}
		}
	}

	my $total_targeted_region = 0;
	if ($self->regions_file) {
		my $regions_file = $self->regions_file;
		my $region_input = new FileHandle ($regions_file);
#		my $header = <$region_input>;
		while (my $line = <$region_input>) {
			chomp($line);
			my ($region_chr,$region_start,$region_stop,$region_name) = split(/\t/, $line);
			my $area = $region_stop - $region_start + 1;
			$total_targeted_region += $area;
		}
	}
#	print Data::Dumper::Dumper(%stats);
#	print Data::Dumper::Dumper(%stats2);

	print OUTFILE "Total Samples $stats{'samples'}\n";
	if ($self->regions_file) {
		print OUTFILE "Total Size of Targeted Regions: $total_targeted_region\n";
	}
	print OUTFILE "Total Unfiltered Variants: $stats{'TotalVariants'}"." - Per Sample:". sprintf("%.3f", ($stats{'TotalVariants'} / $stats{'samples'}))."\n";
	print OUTFILE "Total Variants Passing Strand/Indel Filter: $stats{'Strandfilter_Passed'}{'total'}"." - Per Sample:".sprintf("%.3f", ($stats{'Strandfilter_Passed'}{'total'} / $stats{'samples'}))."\n";
	print OUTFILE "Total Variants Failing Strand/Indel Filter: $stats{'Strandfilter_Failed'}{'total'}"." - Per Sample:".sprintf("%.3f", ($stats{'Strandfilter_Failed'}{'total'} / $stats{'samples'}))."\n";
	print OUTFILE "Total Novel Variants: $stats{'novel'}"." - Per Sample:".sprintf("%.3f", ($stats{'novel'} / $stats{'samples'}))."\n";
	print OUTFILE "Total Variants in dbSNP: $stats{'dbsnp'}"." - Per Sample:".sprintf("%.3f", ($stats{'dbsnp'} / $stats{'samples'}))."\n";
	print OUTFILE "Total FilterPassed Novel Variants: $stats{'Strandfilter_Passed'}{'novel'}"." - Per Sample:".sprintf("%.3f", ($stats{'Strandfilter_Passed'}{'novel'} / $stats{'samples'}))."\n";
	print OUTFILE "Total FilterPassed Variants in dbSNP: $stats{'Strandfilter_Passed'}{'dbsnp'}"." - Per Sample:".sprintf("%.3f", ($stats{'Strandfilter_Passed'}{'dbsnp'} / $stats{'samples'}))."\n";
	print OUTFILE "Total FilterFailed Novel Variants: $stats{'Strandfilter_Failed'}{'novel'}"." - Per Sample:".sprintf("%.3f", ($stats{'Strandfilter_Failed'}{'novel'} / $stats{'samples'}))."\n";
	print OUTFILE "Total FilterFailed Variants in dbSNP: $stats{'Strandfilter_Failed'}{'dbsnp'}"." - Per Sample:".sprintf("%.3f", ($stats{'Strandfilter_Failed'}{'dbsnp'} / $stats{'samples'}))."\n";
	print OUTFILE "\n";
	print OUTFILE "Total Number of Variants That are Singletons: $sum"." - Per Sample:". sprintf("%.3f", ($sum / $stats{'samples'}))."\n";
	print OUTFILE "Total Number of Variants That are Not Singletons: $sum2"." - Per Sample:". sprintf("%.3f", ($sum2 / $stats{'samples'}))."\n";
	my $singleton_sites = 0;
	my $nonsingleton_sites = 0;
	foreach my $strandfilter_status (sort keys %variants) {
		foreach my $dbsnp (sort keys %{$variants{$strandfilter_status}}) {
			print OUTFILE "Total $dbsnp $strandfilter_status SNV Variant Sites: $stats2{$strandfilter_status}{$dbsnp}{'TotalVariantsSNV'}"." - Per Sample:". sprintf("%.3f", ($stats2{$strandfilter_status}{$dbsnp}{'TotalVariantsSNV'} / $stats{'samples'}))."\n";
			print OUTFILE "Total $strandfilter_status $dbsnp Singletons: $stats2{$strandfilter_status}{$dbsnp}{'singletons'}"." - Per Sample:".sprintf("%.3f", ($stats2{$strandfilter_status}{$dbsnp}{'singletons'} / $stats{'samples'}))."\n";
			print OUTFILE "Total $strandfilter_status $dbsnp nonSingletons: $stats2{$strandfilter_status}{$dbsnp}{'nonsingletons'}"." - Per Sample:".sprintf("%.3f", ($stats2{$strandfilter_status}{$dbsnp}{'singletons'} / $stats{'samples'}))."\n";
			$singleton_sites += $stats2{$strandfilter_status}{$dbsnp}{'singletons'};
			$nonsingleton_sites += $stats2{$strandfilter_status}{$dbsnp}{'nonsingletons'};
		}
	}
	print OUTFILE "Total Number of Sites That are Singletons: $singleton_sites\n";
	print OUTFILE "Total Number of Sites That are Not Singletons: $nonsingleton_sites\n";
	print OUTFILE "\n";
	foreach my $variant_type (sort keys %variant_status) {
		print OUTFILE "Total FilterPassed $variant_type"."s: $stats{'Strandfilter_Passed'}{$variant_type}"." - Per Sample:".sprintf("%.3f", ($stats{'Strandfilter_Passed'}{$variant_type} / $stats{'samples'}))."\n";
		if ($variant_type eq "SNP") {
			print OUTFILE "Total FilterPassed Novel $variant_type"."s: $stats2{'Strandfilter_Passed'}{'novel'}{$variant_type}"." - Per Sample:".sprintf("%.3f", ($stats2{'Strandfilter_Passed'}{'novel'}{$variant_type} / $stats{'samples'}))."\n";
			print OUTFILE "Total FilterPassed $variant_type"."s in dbSNP: $stats2{'Strandfilter_Passed'}{'dbsnp'}{$variant_type}"." - Per Sample:".sprintf("%.3f", ($stats2{'Strandfilter_Passed'}{'dbsnp'}{$variant_type} / $stats{'samples'}))."\n";
		}
	}
	foreach my $variant_type (sort keys %variant_status) {
		print OUTFILE "Total FilterFailed $variant_type"."s: $stats{'Strandfilter_Failed'}{$variant_type}"." - Per Sample:".sprintf("%.3f", ($stats{'Strandfilter_Failed'}{$variant_type} / $stats{'samples'}))."\n";
		if ($variant_type eq "SNP") {
			print OUTFILE "Total FilterFailed Novel $variant_type"."s: $stats2{'Strandfilter_Failed'}{'novel'}{$variant_type}"." - Per Sample:".sprintf("%.3f", ($stats2{'Strandfilter_Failed'}{'novel'}{$variant_type} / $stats{'samples'}))."\n";
			print OUTFILE "Total FilterFailed $variant_type"."s in dbSNP: $stats2{'Strandfilter_Failed'}{'dbsnp'}{$variant_type}"." - Per Sample:".sprintf("%.3f", ($stats2{'Strandfilter_Failed'}{'dbsnp'}{$variant_type} / $stats{'samples'}))."\n";
		}
	}
}


=cut
Number of snps, ins, del
Avg Per Sample
Total Number of Sites with Variant
#unique, #dbsnp
	Of each, #snv, #ins, #del, #other
	average per sample
average allele frequency

given roi file, what is target region...
How many singletons are there per sample? 
=cut

#my ($Sample, $SNPsCalled, $WithGenotype, $MetMinDepth, $Reference, $RefMatch, $RefWasHet, $RefWasHom, $Variant, $VarMatch, $HomWasHet, $HetWasHom, $VarMismatch, $VarConcord, $RareHomConcord, $OverallConcord) = split(/\t/, $qc_line);

################################################################################################
# SUBS
#
################################################################################################


#############################################################
# IUPAC to base - convert IUPAC code to variant base
#
#############################################################

sub iupac_to_base
{
	(my $allele1, my $allele2) = @_;
	
	return($allele2) if($allele2 eq "A" || $allele2 eq "C" || $allele2 eq "G" || $allele2 eq "T");
	
	if($allele2 eq "M")
	{
		return("C") if($allele1 eq "A");
		return("A") if($allele1 eq "C");
	}
	elsif($allele2 eq "R")
	{
		return("G") if($allele1 eq "A");
		return("A") if($allele1 eq "G");		
	}
	elsif($allele2 eq "W")
	{
		return("T") if($allele1 eq "A");
		return("A") if($allele1 eq "T");		
	}
	elsif($allele2 eq "S")
	{
		return("C") if($allele1 eq "G");
		return("G") if($allele1 eq "C");		
	}
	elsif($allele2 eq "Y")
	{
		return("C") if($allele1 eq "T");
		return("T") if($allele1 eq "C");		
	}
	elsif($allele2 eq "K")
	{
		return("G") if($allele1 eq "T");
		return("T") if($allele1 eq "G");				
	}	
	
	return($allele2);
}

#############################################################
# ParseBlocks - takes input file and parses it
#
#############################################################

sub trv_to_mutation_type
{
	my $trv_type = shift(@_);
	
	return("Missense_Mutation") if($trv_type eq "missense");	
	return("Nonsense_Mutation") if($trv_type eq "nonsense" || $trv_type eq "nonstop");	
	return("Silent") if($trv_type eq "silent");		
	return("Splice_Site_SNP") if($trv_type eq "splice_site");
	return("Splice_Site_Indel") if($trv_type eq "splice_site_del");		
	return("Splice_Site_Indel") if($trv_type eq "splice_site_ins");		
	return("Frame_Shift_Del") if($trv_type eq "frame_shift_del");		
	return("Frame_Shift_Ins") if($trv_type eq "frame_shift_ins");		
	return("In_Frame_Del") if($trv_type eq "in_frame_del");		
	return("In_Frame_Ins") if($trv_type eq "in_frame_ins");		
	return("RNA") if($trv_type eq "rna");		

	warn "Unknown mutation type $trv_type\n";
	return("Unknown");
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub byChrPos
{
	my ($chrom_a, $pos_a) = split(/\t/, $a);
	my ($chrom_b, $pos_b) = split(/\t/, $b);
	
	$chrom_a =~ s/X/23/;
	$chrom_a =~ s/Y/24/;
	$chrom_a =~ s/MT/25/;
	$chrom_a =~ s/M/25/;
	$chrom_a =~ s/[^0-9]//g;

	$chrom_b =~ s/X/23/;
	$chrom_b =~ s/Y/24/;
	$chrom_b =~ s/MT/25/;
	$chrom_b =~ s/M/25/;
	$chrom_b =~ s/[^0-9]//g;

	$chrom_a <=> $chrom_a
	or
	$pos_a <=> $pos_b;
}

1;
