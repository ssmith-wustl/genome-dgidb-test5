
package Genome::Model::Tools::Capture::BatchSampleQc;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# BatchSampleQcForAnnotation - Merge glfSomatic/Varscan somatic calls in a file that can be converted to MAF format
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	10/23/2009 by D.K.
#	MODIFIED:	10/23/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;
use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Capture::BatchSampleQc {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		bam_files	=> { is => 'Text', doc => "Tab-delimited list of samples and paths to BAM files", is_optional => 1, is_input => 1 },
		snp_files	=> { is => 'Text', doc => "Tab-delimited list of samples and paths to SNP calls from sequencing", is_optional => 0, is_input => 1 },
		genotype_files	=> { is => 'Text', doc => "Tab-delimited list of samples and paths to array genotype data", is_optional => 0, is_input => 1 },		
		output_dir     => { is => 'Text', doc => "Output directory to store QC files", is_optional => 1, is_input => 1, is_output => 1 },
		output_file     => { is => 'Text', doc => "Output file to receive QC results", is_optional => 1, is_input => 1, is_output => 1 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Runs genotype QC on a list of samples"                 
}

sub help_synopsis {
    return <<EOS
This command runs sample genotype QC on a batch of samples
EXAMPLE:	gmt capture batch-sample-qc --snp-files Sample-SNP-Files.tsv --genotype-files Sample-Genotype-Files.tsv --output-dir sample_qc_files --output-file Sample-QC-Results.tsv
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
	my $snp_files = $self->snp_files;
	my $genotype_files = $self->genotype_files;
	my $output_file = $self->output_file;
	my $output_dir = $self->output_dir;

	my %stats = ();

	my $samples_without_genotypes = "";

	## Load the sample snp files ##

	my %sample_bam_files = parse_sample_file_list($self->bam_files) if($self->bam_files);	
	my %sample_snp_files = parse_sample_file_list($snp_files);
	my %sample_genotype_files = parse_sample_file_list($genotype_files);
	
	## Open outfile ##
	
	open(OUTFILE, ">$output_file") or die "Can't open outfile: $!\n";
	print OUTFILE "Sample\tGenotypeFile\tSNPcalls\tSNPsCalled\tWithGenotype\tMetMinDepth\tReference\tRefMatch\tRefWasHet\tRefWasHom\tVariant\tVarMatch\tHomWasHet\tHetWasHom\tVarMismatch\tVarConcord\tRareHomConcord\tOverallConcord\n";

	## Go through each sample with sequencing data ##
	
	my %sample_counted = ();
	
	foreach my $sample_name (keys %sample_snp_files)
	{
		my $sample_qc_result = "NoGenotypes";

		if($sample_genotype_files{$sample_name})
		{
			$stats{'have_snp_and_genotype'}++;
			
			## Determine output file path ##
			
			my $sample_output_file = $output_dir . "/" . $sample_name . ".qc.tsv";
			
			if(-e $sample_output_file)
			{
				## Skip processing and just parse results ##
				$sample_qc_result = parse_qc_results($sample_output_file);
				my ($num_sites, $var_conc, $rare_hom_conc, $overall_conc) = split(/\t/, $sample_qc_result);
				$overall_conc =~ s/\%//;
				$sample_qc_result .= "\tFLAG" if($overall_conc && $overall_conc ne "-" && $overall_conc < 95);
			}

			if($sample_qc_result && $sample_qc_result ne "-\t-\t-\t-" && $sample_qc_result ne "NoGenotypes")
			{
				## Do nothing; we're done ##
				$stats{'qc_is_complete'}++;
			}
			else
			{
				$sample_qc_result = "InProgress";
				$stats{'qc_is_running'}++;
				## Run the sample QC ##
				my $label = "";
				$label = $sample_bam_files{$sample_name} if($sample_bam_files{$sample_name});
				run_genotype_qc($sample_name, $sample_genotype_files{$sample_name}, $sample_snp_files{$sample_name}, $sample_output_file);				
			}

			## Print a sample with both SNP and QC files ##
			print OUTFILE join("\t", $sample_name, $sample_genotype_files{$sample_name}, $sample_snp_files{$sample_name}, $sample_qc_result) . "\n";
			print join("\t", $sample_name, $sample_qc_result) . "\n";
		}
		else
		{
			$stats{'have_snp_only'}++;

			$samples_without_genotypes .= "\n" if($samples_without_genotypes);
			$samples_without_genotypes .= "\t" . $sample_name;

			## Print a sample without genotype file ##
			print OUTFILE join("\t", $sample_name, "-", $sample_snp_files{$sample_name}, $sample_qc_result) . "\n";
		}
	
	
		if(!$sample_counted{$sample_name})
		{
			$stats{'num_samples'}++;
			$sample_counted{$sample_name}++;
		}
	}
	
	## Go through each sample with genotype data ##
	
	foreach my $sample_name (keys %sample_genotype_files)
	{
		if(!$sample_snp_files{$sample_name})
		{
			$stats{'have_genotype_only'}++;
		}

		if(!$sample_counted{$sample_name})
		{
			$stats{'num_samples'}++;
			$sample_counted{$sample_name}++;
		}
	}	
	
	
	close(OUTFILE);


	## Print a summary of the statistics ##
	
	print $stats{'num_samples'} . " samples\n";

	print $stats{'have_genotype_only'} . " have array genotypes but no sequence data\n";

	print $stats{'have_snp_only'} . " have sequence data but no array genotypes\n";
	print "$samples_without_genotypes\n";

	print $stats{'have_snp_and_genotype'} . " have sequence and genotype data\n";
	print "\t" . $stats{'qc_is_complete'} . " have completed QC\n";
	print "\t" . $stats{'qc_is_running'} . " are running QC\n";

	
}




################################################################################################
# Execute - the main program logic
#
################################################################################################

sub run_genotype_qc
{
	my ($sample_name, $genotype_file, $snp_file, $output_file) = @_;

	my $cmd = "gmt analysis lane-qc compare-snps --genotype $genotype_file --variant $snp_file --output-file $output_file";
#	print "RUN: $cmd\n";
	
	system("bsub -q short -R\"select[model != Opteron250 && mem>1000] rusage[mem=1000]\" \"$cmd\"");
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub old_run_genotype_qc
{
	my ($sample_name, $genotype_file, $snp_file, $label) = @_;

#	print "Running Genotype QC for $sample_name...\n";	
	my $qc_result = `gmt analysis lane-qc compare-snps --genotype $genotype_file --variant $snp_file 2>/dev/null`;
	chomp($qc_result);
	
	my ($qc_header, $qc_values) = split(/\n/, $qc_result);
	
	## Convert whitespace to tab-space ##
	$qc_values =~ s/\s+/\t/g;
	
	my @valueContents = split(/\t/, $qc_values);
	my $numContents = @valueContents;
	my $overall_conc = $valueContents[$numContents - 1];
	
	$label = $snp_file if(!$label);
	print OUTFILE join("\t", $sample_name, $genotype_file, $label, $qc_values) . "\n";
	print "$sample_name\t$overall_conc\n";
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub parse_sample_file_list
{
	my $list_file = shift(@_);

	my %files_by_sample = ();

	my $input = Genome::Sys->open_file_for_reading($list_file);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		

		my ($sample_name, $file_path) = split(/\t/, $line);

		my @temp = split(/\-/, $sample_name);
		my $short_sample_name = join("-", $temp[0], $temp[1], $temp[2], $temp[3]);
		
#		$files_by_sample{$sample_name} = $file_path;
		$files_by_sample{$short_sample_name} = $file_path;
	}

	close($input);
	
	return(%files_by_sample);
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub parse_qc_results
{
	my $qc_file = shift(@_);
	my $result = "-\t-\t-\t-";

	if(-e $qc_file)
	{	
		my $input = Genome::Sys->open_file_for_reading($qc_file);
		my $lineCounter = 0;
	
		while (<$input>)
		{
			chomp;
			my $line = $_;
			$lineCounter++;		
			
			my @lineContents = split(/\t/, $line);
			my $numContents = @lineContents; 
			if($numContents > 10 && !($line =~ 'SNPsCalled'))
			{
				my ($SNPfile, $SNPsCalled, $WithGenotype, $MetMinDepth, $Reference, $RefMatch, $RefWasHet, $RefWasHom, $Variant, $VarMatch, $HomWasHet, $HetWasHom, $VarMismatch, $VarConcord, $RareHomConcord, $OverallConcord) = split(/\t/, $line);			
				$result = join("\t", $MetMinDepth, $VarConcord, $RareHomConcord, $OverallConcord);
			}
	
		}
	
		close($input);		
	}
	
	return($result);
}




1;

