
package Genome::Model::Tools::Gatk::GermlineIndelUnifiedGenotyper;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# GermlineIndel - Call the GATK germline indel detection pipeline
#					
#	AUTHOR:		Will Schierding
#
#	CREATED:	03-Mar-2011 by W.S.
#	MODIFIED:	03-Mar-2011 by W.S.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;
use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Gatk::GermlineIndelUnifiedGenotyper {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		bam_file	=> { is => 'Text', doc => "BAM File for Sample", is_optional => 0, is_input => 1 },
		vcf_output_file     => { is => 'Text', doc => "Output file to receive GATK vcf format lines", is_optional => 0, is_input => 1, is_output => 1 },
		verbose_output_file     => { is => 'Text', doc => "STDOUT from GATK", is_optional => 1, is_input => 1, is_output => 1 },
		gatk_params => { is => 'Text', doc => "Parameters for GATK", is_optional => 1, is_input => 1, is_output => 1, default => "-T UnifiedGenotyper -glm DINDEL" },
		reference_fasta => { is => 'Text', doc => "Parameters for GATK", is_optional => 1, is_input => 1, is_output => 1, default => "/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa" },
		path_to_gatk => { is => 'Text', doc => "Path to GATK command", is_optional => 1, is_input => 1, is_output => 1, default => "/gsc/pkg/bio/gatk/GenomeAnalysisTK-1.0.5336/GenomeAnalysisTK.jar" },
	        mb_of_ram => {
	            is => 'Text',
        	    doc => 'The amount of RAM to use, in megabytes',
        	    default => 5000,
	        },
		skip_if_output_present => { is => 'Text', doc => "Skip if output is present", is_optional => 1, is_input => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Runs the GATK germline indel detection pipeline"                 
}

sub help_synopsis {
    return <<EOS
This command runs the GATK indel detection pipeline
EXAMPLE:	gmt gatk germline-indel bam-file file.bam --output-file GATK.indel --bed-output-file GATK.indel.bed
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

	## Run GATK ##
	#java -Xms3000m -Xmx3000m -jar /gsc/pkg/bio/gatk/GenomeAnalysisTK-1.0.5336/GenomeAnalysisTK.jar -R /gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa -T UnifiedGenotyper -glm DINDEL -I /gscmnt/ams1132/info/model_data/2869126180/build106555038//alignments/106555038_merged_rmdup.bam -verbose /gscmnt/sata424/info/medseq/Freimer-Boehnke/ExomeComparison/Agilent/H_HY-01154-lib2/testing/GATK.output.indel_manualrun_5336_Unifiedtest -o /gscmnt/sata424/info/medseq/Freimer-Boehnke/ExomeComparison/Agilent/H_HY-01154-lib2/testing/GATK.output.indel_manualrun_5336_Unifiedtest.vcf

	my $path_to_gatk = $self->path_to_gatk;
	my $gatk_params = $self->gatk_params;
	my $reference_fasta = "-R " . $self->reference_fasta;
	my $output_file = "-o " . $self->vcf_output_file;	
	my $bam_input = "-I ".$self->bam_file;
	my $ram = $self->mb_of_ram;
	my $cmd = 'java -Xms'.$ram.'m -Xmx'.$ram.'m -jar ';
	$cmd .= join(" ", $path_to_gatk, $gatk_params, $reference_fasta, $bam_input, $output_file);
	
	## Optionally append BED output file ##

	if($self->verbose_output_file) {
		$cmd .= " -verbose " . $self->verbose_output_file;
	}

	## Run GATK Command ##
	my $return;
	if($self->skip_if_output_present && -e $output_file)
	{
		
	}
	else
	{
		system("touch $output_file"); # This will create an empty output file to help prevent GATK from crashing 
		$return = Genome::Sys->shellcmd(
                           cmd => "$cmd",
                           output_files => [$output_file],
                           skip_if_output_is_present => 0,
                       );
		unless($return) { 
			$self->error_message("Failed to execute GATK: GATK Returned $return");
			die $self->error_message;
		}
	}

	return $return;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}

1;

