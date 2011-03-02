
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

## Declare global statistics hash ##

my %stats = ();

class Genome::Model::Tools::Capture::GermlineMafStatistics {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		data_dir	=> { is => 'Text', doc => "Base Data Directory i.e. /gscmnt/sata424/info/medseq/Freimer-Boehnke/Analysis-1033Samples/ " , is_optional => 0},
		project_name	=> { is => 'Text', doc => "Name of the project i.e. ASMS" , is_optional => 0},
		model_list	=> { is => 'Text', doc => "Same as input to germline pipeline, no headers, (space or tab delim) model_id, sample_name, build_id, build_status, build_dir" , is_optional => 0},
		maf_file	=> { is => 'Text', doc => "Maf File To Read" , is_optional => 0},
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

	my $data_dir = $self->data_dir;
	my $project_name = $self->project_name;
	my $output_file = $self->output_file;
	my $model_list_file = $self->model_list;
	my $maf_file = $self->maf_file;

	my %model_hash;
	my $model_input = new FileHandle ($model_list_file);
	while (my $line = <$model_input>) {
		chomp($line);
		$line =~ s/\s+/\t/g;
		my ($model_id, $sample_name, $build_id, $build_status, $builddir) = split(/\t/, $line);
		$model_hash{$sample_name} = "$model_id\t$build_id\t$builddir";
	}
	my $model_count = 0;
	foreach (sort keys %model_hash) {
		$model_count++;
	}
	print "Model List Loaded, $model_count Models in List\n";

	## Open the outfile ##
	my $outfile = "$data_dir/$output_file";
	open(OUTFILE, ">$outfile") or die "Can't open output file: $!\n";
	foreach my $sample_name (sort keys %model_hash) {
		my $sample_output_dir = $data_dir . "/" . $sample_name;
		my ($model_id, $build_id, $build_dir) = split(/\t/, $model_hash{$sample_name});
	}
	my %variant_status;
	my %samples;
	my $input = new FileHandle ($maf_file);
	my $header = <$maf_file>;
	while (my $line = <$maf_file>) {
		chomp($line);
		my ($gene_name,$gene_id,$center,$ref_build,$chromosome,$chr_start,$chr_stop,$strand,$mutation_type,$variant_type,$ref,$tumor_gt_allele1,$tumor_gt_allele2,$dbsnp_rs,$dbsnp_status,$sample_name,$sample_name2,$ref2,$ref3,$val1,$val2,$val3,$val4,$strandfilter_status,$val_status,$mut_status,$val_method,$sequence_phase,$sequence_source,$score,$bam_file,$sequencer, @annotation) = split(/\t/, $line);
		$samples{$sample_name}++;
		$stats{'TotalVariants'}++;
		if ($dbsnp_rs =~ m/novel/i) {
			my $dbsnp = 'novel';
			$variant_status{$strandfilter_status}{$dbsnp}{$variant_type} = $line;
		}
		else {
			my $dbsnp = 'dbsnp';
			$variant_status{$strandfilter_status}{$dbsnp}{$variant_type} = $line;
		}
	}

	foreach my $strandfilter_status (sort keys %variant_status) {
		$stats{$strandfilter_status}++;
		foreach my $dbsnp (sort keys %{$variant_status{$strandfilter_status}}) {
			$stats{$dbsnp}++;
			$stats{$strandfilter_status}{$dbsnp}++;
			foreach my $variant_type (sort keys %{$variant_status{$strandfilter_status}}) {
				$stats{$strandfilter_status}{$variant_type}++;
				$stats{$strandfilter_status}{$dbsnp}{$variant_type}++;
			}
		}
	}

	print "Total Variants $stats{'TotalVariants'}\n";
	print "Total Variants Passing Strand/Indel Filter $stats{'Strandfilter_Passed'}\n";
	print "Total Variants Failing Strand/Indel Filter $stats{'Strandfilter_Failed'}\n";
	print "Total Novel Variants $stats{'novel'}\n";
	print "Total Variants in dbSNP $stats{'dbsnp'}\n";
	print "Total Filtered Novel Variants $stats{'Strandfilter_Passed'}{'novel'}\n";
	print "Total Filtered Variants in dbSNP $stats{'Strandfilter_Passed'}{'dbsnp'}\n";
	print "Total FilterFailed Novel Variants $stats{'Strandfilter_Failed'}{'novel'}\n";
	print "Total FilterFailed Variants in dbSNP $stats{'Strandfilter_Failed'}{'dbsnp'}\n";
	
	foreach my $variant_type (sort keys %{$variant_status{'Strandfilter_Passed'}}) {
		print "Total Filtered $variant_type"."s $stats{'Strandfilter_Passed'}{$variant_type}\n";
		print "Total Filtered Novel $variant_type"."s $stats{'Strandfilter_Passed'}{'novel'}{$variant_type}\n";
		print "Total Filtered $variant_type"."s in dbSNP $stats{'Strandfilter_Passed'}{'dbsnp'}{$variant_type}\n";
	}
	foreach my $variant_type (sort keys %{$variant_status{'Strandfilter_Failed'}}) {
		print "Total FilterFailed $variant_type"."s $stats{'Strandfilter_Failed'}{$variant_type}\n";
		print "Total FilterFailed Novel $variant_type"."s $stats{'Strandfilter_Failed'}{'novel'}{$variant_type}\n";
		print "Total FilterFailed $variant_type"."s in dbSNP $stats{'Strandfilter_Failed'}{'dbsnp'}{$variant_type}\n";
	}
}


=cut
Number of samples
Number of snps, ins, del
Avg Per Sample
#unique, #dbsnp
	Of each, #snv, #ins, #del, #other
	average per sample
average allele frequency

given roi file, what is target region...
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
