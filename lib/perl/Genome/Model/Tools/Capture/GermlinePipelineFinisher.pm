
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
		make_vcf	=> { is => 'Text', doc => "Make a vcf file for each sample" , is_optional => 1, default => "0"},
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

	my $return = 1;

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
		my ($model_id, $sample_name, $build_id, $build_status, $build_dir, $bam_file) = split(/\t/, $line);
		if (exists $sample_list{$sample_name}) {
			$model_hash{$sample_name} = "$model_id\t$build_id\t$build_dir\t$bam_file";
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
	my $firstfile = 1;
	foreach my $sample_name (sort keys %model_hash) {
		my $sample_output_dir = $data_dir . "/" . $sample_name;
		my ($model_id, $build_id, $build_dir, $bam_file) = split(/\t/, $model_hash{$sample_name});
		my $maf_file = $sample_output_dir . "/merged.germline.ROI.tier1.out.maf";
		if (-e $maf_file) {
			my $input = new FileHandle ($maf_file);
			my $header = <$input>;
			if ($firstfile) {
				print OUTFILE "$header";
				$firstfile = 0;
			}
			while (<$input>) {
				my $line = $_;
				print OUTFILE "$line";
			}
			close($input);
		}
		else {
			print "Sample $sample_name does not have maf file: $maf_file\n";
		}
	}

	if ($self->make_vcf) {
		foreach my $sample_name (sort keys %model_hash) {
			my $sample_output_dir = $data_dir . "/" . $sample_name . "/";
			my $outfile = $sample_output_dir . "merged.germline.ROI.tier1.out.vcf";
			open(OUTFILE, ">$outfile") or die "Can't open output file: $!\n";
			my ($model_id, $build_id, $build_dir, $bam_file) = split(/\t/, $model_hash{$sample_name});
			my $snp_file = $build_dir . "/snp_related_metrics/snps_all_sequences.filtered";
			my $indel_file = $build_dir . "/snp_related_metrics/indels_all_sequences.filtered";
			unless ($bam_file) {
				my $model = Genome::Model->get($model_id);
				my $build = $model->last_succeeded_build;
				$bam_file = $build->whole_rmdup_bam_file;
			}
			my $snv_filter = $sample_output_dir.'/merged.germline.snp.ROI.tier1.out.strandfilter';
			my $snv_filter_fail;
			my $indel_filter;
			my $indel_filter_fail;
			my $snv_annotation;
			my $indel_annotation;
			my $indel;
			my $varfile;
			my $dbsnp = $sample_output_dir.'/merged.germline.snp.ROI.tier1.out.dbsnp';
			if (-e $snv_filter) {
				$snv_filter = $sample_output_dir.'/merged.germline.snp.ROI.tier1.out.strandfilter';
				$snv_filter_fail = $sample_output_dir.'/merged.germline.snp.ROI.tier1.out.strandfilter_filtered';
				$indel_filter = $sample_output_dir.'/merged.germline.indel.ROI.tier1.out.strandfilter';
				$indel_filter_fail = $sample_output_dir.'/merged.germline.indel.ROI.tier1.out.strandfilter_filtered';
				$indel_annotation = $sample_output_dir.'/annotation.germline.indel.transcript';
				$snv_annotation = $sample_output_dir.'/annotation.germline.snp.transcript';
				$indel = $sample_output_dir.'/merged.germline.indel.ROI.tier1.out';
				$varfile = $sample_output_dir.'/merged.germline.snp.ROI.tier1.out';
			}
			else {
				$snv_filter = $sample_output_dir.'/merged.germline.snp.ROI.strandfilter';
				$snv_filter_fail = $sample_output_dir.'/merged.germline.snp.ROI.strandfilter_filtered';
				$indel_filter = $sample_output_dir.'/merged.germline.indel.ROI.strandfilter';
				$indel_filter_fail = $sample_output_dir.'/merged.germline.indel.ROI.strandfilter_filtered';
				$indel_annotation = $sample_output_dir.'/annotation.germline.indel.strandfilter.transcript';
				$snv_annotation = $sample_output_dir.'/annotation.germline.snp.strandfilter.transcript';
				$indel = $sample_output_dir.'/merged.germline.indel.ROI.strandfilter.tier1.out';
				$varfile = $sample_output_dir.'/merged.germline.snp.ROI.strandfilter.tier1.out';
			}
			my $base_cmd = "perl -I ~/git-dir/ `which gmt` germline vcf-maker --bam-file $bam_file --build-id $build_id --dbsnp-file $dbsnp --indel-annotation-file $indel_annotation --indel-failfiltered-file $indel_filter_fail --indel-file $indel --indel-filtered-file $indel_filter --output-file $outfile --snv-annotation-file $snv_annotation --snv-failfiltered-file $snv_filter_fail --snv-filtered-file $snv_filter --variant-file $varfile --build 36 --center WUGC --project-name $project_name --sequence-phase 4 --sequence-source Capture --sequencer Illumina_GAIIx_or_Hiseq";
#			my $cmd = "bsub -u wschierd\@genome.wustl.edu -q apipe -R\"select[type==LINUX64 && model != Opteron250 && mem>4000] rusage[mem=4000]\" -M 4000000 -J $job_name -o $output_name -e $error_name \"$base_cmd\"");
			my $cmd = "bsub -q apipe -R\"select[type==LINUX64 && model != Opteron250 && mem>4000] rusage[mem=4000]\" -M 4000000 \"$base_cmd\"";
			system($cmd);
#			$return = Genome::Sys->shellcmd(
#	                           cmd => "$cmd",
#	                           output_files => [$outfile],
#	                           skip_if_output_is_present => 0,
#	                       );
#			unless($return) { 
#				$self->error_message("Failed to execute Vcf Maker: Returned $return");
#				die $self->error_message;
#			}
		}
	}

	return $return;

}




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
