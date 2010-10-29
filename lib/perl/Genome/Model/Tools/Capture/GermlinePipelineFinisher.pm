
package Genome::Model::Tools::Capture::GermlinePipelineFinisher;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# GermlinePipelineFinisher - Generate MAF File, Get dbsnp output, and strandfilter -- for GERMLINE events
#					
#	AUTHOR:		Will Schierding (wschierd@genome.wustl.edu)
#
#	CREATED:	09/29/2010 by W.S.
#	MODIFIED:	09/29/2010 by W.S.
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

class Genome::Model::Tools::Capture::GermlinePipelineFinisher {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		data_dir	=> { is => 'Text', doc => "Base Data Directory i.e. /gscmnt/sata424/info/medseq/Freimer-Boehnke/Analysis-1033Samples/ " , is_optional => 0},
		project_name	=> { is => 'Text', doc => "Name of the project i.e. ASMS" , is_optional => 0},
		sample_list	=> { is => 'Text', doc => "File of sample names to include, 1 name per line, no headers" , is_optional => 0},
		model_list	=> { is => 'Text', doc => "Same as input to germline pipeline, no headers, (space or tab delim) model_id, sample_name, build_id, build_status, build_dir" , is_optional => 0},
		output_file	=> { is => 'Text', doc => "Name of MAF File" , is_optional => 0},
		center 		=> { is => 'Text', doc => "Genome center name" , is_optional => 1, default => "genome.wustl.edu"},
		build 		=> { is => 'Text', doc => "Reference genome build" , is_optional => 1, default => "36"},
		sequence_phase	=> { is => 'Text', doc => "Sequencing phase" , is_optional => 1, default => "4"},
		sequence_source	=> { is => 'Text', doc => "Sequence source" , is_optional => 1, default => "Capture"},
		sequencer	=> { is => 'Text', doc => "Sequencing platform name" , is_optional => 1, default => "IlluminaGAIIx"},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Generate MAF File, Get dbsnp output, and strandfilter -- for GERMLINE projects"                 
}

sub help_synopsis {
    return <<EOS
Generate MAF File, Get dbsnp output, and strandfilter -- for GERMLINE events
EXAMPLE:	gmt capture germline-pipeline-finisher
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
	my $sample_list_file = $self->sample_list;
	my $model_list_file = $self->model_list;	

	my $center = $self->center;
	my $build = $self->build;
	my $sequence_phase = $self->sequence_phase;
	my $sequence_source = $self->sequence_source;
	my $sequencer = $self->sequencer;

	my %sample_list;
	my $sample_input = new FileHandle ($sample_list_file);
	while (my $sample = <$sample_input>) {
		chomp($sample);
		$sample_list{$sample}++;
	}
	my $sample_count = 0;
	foreach (sort keys %sample_list) {
		$sample_count++;
	}
	print "Sample List Loaded, $sample_count Samples in List\n";

	my %model_hash;
	my $model_input = new FileHandle ($model_list_file);
	while (my $line = <$model_input>) {
		chomp($line);
		$line =~ s/\s+/\t/g;
		my ($model_id, $sample_name, $build_id, $build_status, $builddir) = split(/\t/, $line);
		if (exists $sample_list{$sample_name}) {
			$model_hash{$sample_name} = "$model_id\t$build_id\t$builddir";
		}
	}
	my $model_count = 0;
	foreach (sort keys %model_hash) {
		$model_count++;
	}
	print "Model List Loaded, $model_count Models in List\n";

	## Open the outfile ##
	my $outfile = $data_dir . $output_file;
	open(OUTFILE, ">$outfile") or die "Can't open output file: $!\n";
	print OUTFILE join("\t", "Hugo_Symbol","Entrez_Gene_Id","GSC_Center","NCBI_Build","Chromosome","Start_position","End_position","Strand","Variant_Classification","Variant_Type","Reference_Allele","Variant_Allele1","Variant_Allele2", "dbSNP_RS","dbSNP_Val_Status","Sample_Barcode","Sample_Barcode","Match_Norm_Seq_Allele1","Match_Norm_Seq_Allele2","Validation_Allele1","Validation_Allele2","Match_Norm_Validation_Allele1","Match_Norm_Validation_Allele2", "Verification_Status","Validation_Status","Mutation_Status","Validation_Method","Sequencing_Phase","Sequence_Source","Score","BAM_file","Sequencer","chromosome_name_WU","start_WU","stop_WU","reference_WU","variant_WU", "type_WU","gene_name_WU","transcript_name_WU","transcript_species_WU","transcript_source_WU","transcript_version_WU","strand_WU","transcript_status_WU","trv_type_WU","c_position_WU","amino_acid_change_WU","ucsc_cons_WU", "domain_WU","all_domains_WU","deletion_substructures_WU","transcript_error_WU") . "\n";

	foreach my $sample_name (sort keys %model_hash) {
		my $sample_output_dir = $data_dir . "/" . $sample_name;
		my ($model_id, $build_id, $build_dir) = split(/\t/, $model_hash{$sample_name});
		## get the bam file ##
		my $bam_file = $build_dir . "/alignments/" . $build_id . "_merged_rmdup.bam";
		my $snp_file = $build_dir . "/snp_related_metrics/snps_all_sequences.filtered";
		my $indel_file = $build_dir . "/snp_related_metrics/indels_all_sequences.filtered";
		my $snv_tier1_file = $sample_output_dir . "/merged.germline.snp.ROI.tier1.out";
		my $indel_tier1_file = $sample_output_dir . "/merged.germline.indel.ROI.tier1.out";
		my $snv_annotation_file = $sample_output_dir . "/annotation.germline.snp.transcript";
		my $indel_annotation_file = $sample_output_dir . "/annotation.germline.indel.transcript";

		if(-e $snv_tier1_file && -e $snv_annotation_file)
		{
			## Build or access the dbSNP file ##
			
			my $dbsnp_file = $snv_tier1_file . ".dbsnp";
			if(!(-e $dbsnp_file))
			{
				my $cmd = "gmt annotate lookup-variants --variant-file $snv_tier1_file --report-mode known-only --append-rs-id --output-file $snv_tier1_file.dbsnp";
				system($cmd);
			}
	
			## Load dbSNPs ##
			
			my %dbsnp_rs_ids = load_dbsnps($snv_tier1_file . ".dbsnp");

			## Build Strandfilter File

			my $strandfilter_file = $snv_tier1_file . '.strandfilter';
			my $strandfilter_junk_file = $snv_tier1_file . '.strandfilter_filtered';
			if(!(-e $strandfilter_file))
			{
				my $strandfilter_cmd = "gmt somatic strand-filter --variant-file $snv_tier1_file --tumor-bam $bam_file --output-file $strandfilter_file --filtered-file $strandfilter_junk_file";
				system ($strandfilter_cmd);
			}

			## Load strandfilter ##
			
			my %strandfilter_lines = load_strandfilter($strandfilter_file, $strandfilter_junk_file);
	
			## Load the SNVs ##
		
			my %snvs = load_mutations($snv_tier1_file);
			my %snv_annotation = load_annotation($snv_annotation_file);

			foreach my $key (sort byChrPos keys %snvs)
			{
				$stats{'tier1_snvs'}++;
			
				my ($chromosome, $chr_start, $chr_stop, $ref, $var) = split(/\t/, $key);
				my $snv = $snvs{$key};
				my $strand = "+";
			
				my @temp = split("\t", $snv);
			
				if($snv_annotation{$key})
				{
					$stats{'tier1_snvs_with_annotation'}++;
					my @annotation = split(/\t/, $snv_annotation{$key});
					my $gene_name = $annotation[6];
					my $tumor_gt_allele1 = $annotation[3];
					my $tumor_gt_allele2 = $annotation[4];


					## Get the gene ID ##
					my $gene_id = 0;

					my @ea = GSC::EntityAlias->get(alias => "$gene_name", alias_source => "HUGO", entity_type_name => "gene sequence tag");
					
					if(@ea)
					{
						my @tags = GSC::Sequence::Tag->get(stag_id => [ map {$_->entity_id} @ea ]);
						if(@tags)
						{
							$gene_id = $tags[0]->ref_id;						
						}
					}

					
					my $trv_type = $annotation[13];
	
					my $mutation_type = trv_to_mutation_type($trv_type);

					##Get Strandfilter Status
					my $strandfilter_status = $strandfilter_lines{$key};

					## Get dbSNP Status 	
					my $dbsnp_rs = "novel";
					my $dbsnp_status = "unknown";

					if($dbsnp_rs_ids{$key})
					{
						$dbsnp_rs = $dbsnp_rs_ids{$key};
						$dbsnp_status = "unknown";
					}

					print OUTFILE join("\t", $gene_name,$gene_id,$center,$build,$chromosome,$chr_start,$chr_stop,$strand,$mutation_type,"SNP",$ref,$tumor_gt_allele1,$tumor_gt_allele2,$dbsnp_rs,$dbsnp_status,$sample_name,$sample_name,$ref,$ref,"","","","",$strandfilter_status,"Unknown","Germline",$sequence_phase,$sequence_source,"","1",$bam_file,$sequencer, @annotation) . "\n";

					$stats{'tier1_snvs_written'}++;
	
				}
				else
				{
					warn "No annotation for $key in $snv_annotation_file!\n";
				}
			}
		}

		## Write indels to file ##
		my %indels_written = ();
	
		if(-e $indel_tier1_file && -e $indel_annotation_file)
		{
			## Load the Indels ##

			my %indels = load_mutations($indel_tier1_file);
			my %indel_annotation = load_annotation($indel_annotation_file);
	
			## Build Strandfilter File
			my $strandfilter_file = $sample_output_dir . '/indel.tier1.strandfilter';
			my $strandfilter_junk_file = $sample_output_dir . '/indel.tier1.strandfilter_filtered';
			if(!(-e $strandfilter_file))
			{
				my $strandfilter_cmd = "gmt somatic filter-false-indels --variant-file $indel_tier1_file --bam-file $bam_file --output-file $strandfilter_file --filtered-file $strandfilter_junk_file";
				system ($strandfilter_cmd);
			}
			## Load strandfilter ##
			my %strandfilter_lines = load_strandfilter($strandfilter_file, $strandfilter_junk_file);

			foreach my $key (sort byChrPos keys %indels)
			{
				$stats{'tier1_indels'}++;
				
				my ($chromosome, $chr_start, $chr_stop, $ref, $var) = split(/\t/, $key);
				my $indel = $indels{$key};
				my $strand = "+";
				
				my $variant_type = "Unknown";
				
				if($ref eq "0" || $ref eq "-" || length($var) > 1)
				{
					$variant_type = "Ins";
				}
				else
				{
					$variant_type = "Del";
				}
				
				my @temp = split("\t", $indel);
				
				if($indel_annotation{$key})
				{
					$stats{'tier1_indels_with_annotation'}++;
					my @annotation = split(/\t/, $indel_annotation{$key});

					my $tumor_gt_allele1 = $annotation[3];
					my $tumor_gt_allele2 = $annotation[4];

					my $gene_name = $annotation[6];
	
					## Get the gene ID ##
					my $gene_id = 0;
	
					my @ea = GSC::EntityAlias->get(alias => "$gene_name", alias_source => "HUGO", entity_type_name => "gene sequence tag");
						
					if(@ea)
					{
						my @tags = GSC::Sequence::Tag->get(stag_id => [ map {$_->entity_id} @ea ]);
						if(@tags)
						{
							$gene_id = $tags[0]->ref_id;						
						}
					}
		
					my $trv_type = $annotation[13];
	
					my $mutation_type = trv_to_mutation_type($trv_type);

					##Get Strandfilter Status
					my $strandfilter_status = $strandfilter_lines{$key};

					## Get dbSNP Status 	
					my $dbsnp_rs = "novel(indel)";
					my $dbsnp_status = "unknown";

					my $indel_key = "$chromosome\t$chr_start\t$chr_stop\t$variant_type";
					$indels_written{$indel_key} = 1;

					print OUTFILE join("\t", $gene_name,$gene_id,$center,$build,$chromosome,$chr_start,$chr_stop,$strand,$mutation_type,$variant_type,$ref,$tumor_gt_allele1,$tumor_gt_allele2,$dbsnp_rs,$dbsnp_status,$sample_name,$sample_name,$ref,$ref,"","","","",$strandfilter_status,"Unknown","Germline",$sequence_phase,$sequence_source,"","1",$bam_file,$sequencer, @annotation) . "\n";				
					$stats{'tier1_indels_written'}++;
				}
				else
				{
					warn "No annotation for $key in $indel_annotation_file!\n";
				}
			}
		}
	}
	$stats{'tier1_snvs_not_included'} = 0 if(!$stats{'tier1_snvs_not_included'});

	$stats{'tier1_snvs'} = 0 if(!$stats{'tier1_snvs'});
	$stats{'tier1_snvs_not_included'} = 0 if(!$stats{'tier1_snvs_not_included'});
	$stats{'tier1_snvs_with_annotation'} = 0 if(!$stats{'tier1_snvs_with_annotation'});
	$stats{'tier1_snvs_written'} = 0 if(!$stats{'tier1_snvs_written'});
	$stats{'tier1_indels'} = 0 if(!$stats{'tier1_indels'});
	$stats{'tier1_indels_not_included'} = 0 if(!$stats{'tier1_indels_not_included'});
	$stats{'tier1_indels_with_annotation'} = 0 if(!$stats{'tier1_indels_with_annotation'});
	$stats{'tier1_indels_written'} = 0 if(!$stats{'tier1_indels_written'});	

	print $stats{'tier1_snvs'} . " tier 1 SNVs\n";
	print $stats{'tier1_snvs_not_included'} . " not included in target list\n";
	print $stats{'tier1_snvs_with_annotation'} . " met criteria and had annotation\n";
	print $stats{'tier1_snvs_written'} . " were written to MAF file\n\n";

	print $stats{'tier1_indels'} . " tier 1 Indels\n";
	print $stats{'tier1_indels_not_included'} . " not included in target list\n";
	print $stats{'tier1_indels_with_annotation'} . " met criteria and had annotation\n";
	print $stats{'tier1_indels_written'} . " were written to MAF file\n";

}




################################################################################################
# SUBS
#
################################################################################################

sub load_mutations
{  
	my $variant_file = shift(@_);
	my $input = new FileHandle ($variant_file);
	my $lineCounter = 0;

	my %mutations = ();

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $chromosome, my $chr_start, my $chr_stop, my $ref, my $var) = split(/\t/, $line);
	
		$var = iupac_to_base($ref, $var);
	
		my $key = join("\t", $chromosome, $chr_start, $chr_stop, $ref, $var);
		
		$mutations{$key} = $line;		
	}
	
	close($input);


	return(%mutations);
}


sub load_annotation
{  
	my $variant_file = shift(@_);
	my $input = new FileHandle ($variant_file);
	my $lineCounter = 0;

	my %annotation = ();

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $chromosome, my $chr_start, my $chr_stop, my $ref, my $var) = split(/\t/, $line);

		my $key = join("\t", $chromosome, $chr_start, $chr_stop, $ref, $var);
		
		$annotation{$key} = $line;		
	}
	
	close($input);


	return(%annotation);
}

sub load_dbsnps
{  
	my $variant_file = shift(@_);
	my $input = new FileHandle ($variant_file);
	my $lineCounter = 0;

#	print "Parsing $variant_file\n";

	my %mutations = ();

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $chromosome, my $chr_start, my $chr_stop, my $ref, my $var) = split(/\t/, $line);
		my @lineContents = split(/\t/, $line);
		my $numContents = @lineContents;
		
		my $dbsnp_rs_id = $lineContents[$numContents - 1];
		my $key = join("\t", $chromosome, $chr_start, $chr_stop, $ref, $var);
		
		$mutations{$key} = $dbsnp_rs_id;
	}
	
	close($input);

	print "$lineCounter dbSNPs loaded\n";

	return(%mutations);
}

sub load_strandfilter
{  
	my $strandfilter_file = shift(@_);
	my $strandfilter_junk_file = shift(@_);
	my $strandfilter = new FileHandle ($strandfilter_file);
	my $strandfilter_junk = new FileHandle ($strandfilter_junk_file);

	my $lineCounter = 0;
	my $lineCounter2 = 0;
	my %mutations = ();

	while (my $line = <$strandfilter>)
	{
		chomp($line);
		$lineCounter++;
		
		(my $chromosome, my $chr_start, my $chr_stop, my $ref, my $var) = split(/\t/, $line);
		my $key = join("\t", $chromosome, $chr_start, $chr_stop, $ref, $var);
		$mutations{$key} = "Strandfilter_Passed";
	}
	close($strandfilter);
	while (my $line = <$strandfilter_junk>)
	{
		chomp($line);
		$lineCounter2++;
		
		(my $chromosome, my $chr_start, my $chr_stop, my $ref, my $var) = split(/\t/, $line);
		my $key = join("\t", $chromosome, $chr_start, $chr_stop, $ref, $var);
		$mutations{$key} = "Strandfilter_Failed";
	}
	close($strandfilter_junk);

	print "$lineCounter strandfilter_passed\n";
	print "$lineCounter2 strandfilter_failed\n";

	return(%mutations);
}

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
	$chrom_a =~ s/[^0-9]//g;

	$chrom_b =~ s/X/23/;
	$chrom_b =~ s/Y/24/;
	$chrom_b =~ s/MT/25/;
	$chrom_b =~ s/[^0-9]//g;

	$chrom_a <=> $chrom_a
	or
	$pos_a <=> $pos_b;
}

1;
