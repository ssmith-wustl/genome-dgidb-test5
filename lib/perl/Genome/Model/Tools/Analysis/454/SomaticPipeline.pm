
package Genome::Model::Tools::Analysis::454::SomaticPipeline;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# SomaticPipeline - Runs the VarScan somatic pipeline on matched tumor-normal data
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	02/25/2009 by D.K.
#	MODIFIED:	02/25/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Analysis::454::SomaticPipeline {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		patients_file	=> { is => 'Text', doc => "Tab-delimited file of normal and tumor" },
		output_dir	=> { is => 'Text', doc => "Output directory for 454 data. Will create somatic_pipeline in each tumor sample dir" },
		aligner		=> { is => 'Text', doc => "Aligner to use" },
		reference		=> { is => 'Text', doc => "Reference sequence [default=Hs36 ssaha2]", is_optional => 1 },
		skip_if_output_present	=> { is => 'Text', doc => "Skip if output present", is_optional => 1 },		
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Runs the VarScan somatic pipeline on matched normal-tumor samples"                 
}

sub help_synopsis {
    return <<EOS
This command runs the VarScan somatic pipeline on matched normal-tumor samples
EXAMPLE:	gmt analysis 454 somatic-pipeline --patients-file data/paired-normal-tumor.tsv --output-dir data --aligner ssaha2
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
	my $patients_file = $self->patients_file;
	my $output_dir = $self->output_dir;
	my $aligner = $self->aligner;

	if(!(-e $patients_file))
	{
		die "Error: Samples file not found!\n";
	}

	my $input = new FileHandle ($patients_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	
		my ($normal_sample_name, $tumor_sample_name) = split(/\t/, $line);			
		
		## Identify BAM files ##
		my $normal_sample_output_dir = $output_dir . "/" . $normal_sample_name;
		my $normal_bam_file = $normal_sample_output_dir . "/" . $aligner . "_out/$normal_sample_name.$aligner.bam";

		my $tumor_sample_output_dir = $output_dir . "/" . $tumor_sample_name;
		my $tumor_bam_file = $tumor_sample_output_dir . "/" . $aligner . "_out/$tumor_sample_name.$aligner.bam";

		if(-e $normal_bam_file && -e $tumor_bam_file)
		{
			print "$tumor_sample_name\t$normal_bam_file\t$tumor_bam_file\n";
			
			my $varscan_output_dir = $tumor_sample_output_dir . "/varscan_somatic";
			mkdir($varscan_output_dir) if(!(-d $varscan_output_dir));

			open(SCRIPT, ">$varscan_output_dir/script_pipeline.sh") or die "Can't open outfile: $!\n";
			print SCRIPT "#!/gsc/bin/sh\n";
			
			my $cmd = "gmt varscan somatic --normal-bam $normal_bam_file --tumor-bam $tumor_bam_file --output $varscan_output_dir/varScan.output";
#			print SCRIPT "$cmd\n";

			$cmd = "gmt capture format-snvs --variant $varscan_output_dir/varScan.output.snp --output $varscan_output_dir/varScan.output.snp.formatted";
			print SCRIPT "$cmd\n";

			$cmd = "gmt capture format-indels --variant $varscan_output_dir/varScan.output.indel --output $varscan_output_dir/varScan.output.indel.formatted";
			print SCRIPT "$cmd\n";

			$cmd = "gmt somatic monorun-filter --tumor-bam $tumor_bam_file --variant-file $varscan_output_dir/varScan.output.indel.formatted --output-file $varscan_output_dir/varScan.output.indel.formatted.filter";
			print SCRIPT "$cmd\n";

			$cmd = "gmt somatic filter-false-positives --analysis-type capture --bam-file $tumor_bam_file --variant-file $varscan_output_dir/varScan.output.snp.formatted --output-file $varscan_output_dir/varScan.output.snp.formatted.filter --filtered-file $varscan_output_dir/varScan.output.snp.formatted.filter.removed";
			print SCRIPT "$cmd\n";

			## Identify novel ##
			
			$cmd = "gmt annotate lookup-variants --variant $varscan_output_dir/varScan.output.indel.formatted.filter --output $varscan_output_dir/varScan.output.indel.formatted.filter.novel --filter-out-submitters=\"SNP500CANCER,OMIMSNP,CANCER-GENOME,CGAP-GAI,LCEISEN,ICRCG\"";
			print SCRIPT "$cmd\n";

			$cmd = "gmt annotate lookup-variants --variant $varscan_output_dir/varScan.output.snp.formatted.filter --output $varscan_output_dir/varScan.output.snp.formatted.filter.novel --filter-out-submitters=\"SNP500CANCER,OMIMSNP,CANCER-GENOME,CGAP-GAI,LCEISEN,ICRCG\"";
			print SCRIPT "$cmd\n";

			close(SCRIPT);

			system("bsub -q long -R\"select[type==LINUX64 && model != Opteron250 && mem>2000 && tmp>20000] rusage[mem=2000]\" -oo $varscan_output_dir/script_pipeline.sh.out sh $varscan_output_dir/script_pipeline.sh");

			## Process the results ##
			
			
		}
	}
	
	close($input);

	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

