
package Genome::Model::Tools::Gatk::GermlineIndel;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# GermlineIndel - Call the GATK germline indel detection pipeline
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	15-Jul-2010 by D.K.
#	MODIFIED:	15-Jul-2010 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;
use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Gatk::GermlineIndel {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		bam_file	=> { is => 'Text', doc => "BAM File for Sample", is_optional => 0, is_input => 1 },
		output_file     => { is => 'Text', doc => "Output file to receive formatted lines", is_optional => 0, is_input => 1, is_output => 1 },
		bed_output_file => { is => 'Text', doc => "Optional abbreviated output in BED format", is_optional => 1, is_input => 1, is_output => 1 },
		formatted_file => { is => 'Text', doc => "Optional output file of indels in annotation format", is_optional => 1, is_input => 1, is_output => 1 },
		gatk_params => { is => 'Text', doc => "Parameters for GATK", is_optional => 1, is_input => 1, is_output => 1, default => "-R /gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa -T IndelGenotyperV2 --window_size 300" },
		path_to_gatk => { is => 'Text', doc => "Path to GATK command", is_optional => 1, is_input => 1, is_output => 1, default => "java  -Xms3000m -Xmx3000m -jar /gsc/scripts/lib/java/GenomeAnalysisTK.jar" },
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
	my $path_to_gatk = $self->path_to_gatk;
	my $gatk_params = $self->gatk_params;
	#-I /gscmnt/sata905/info/model_data/2858219475/build103084961/alignments/103084961_merged_rmdup.bam
	#-I /gscmnt/sata871/info/model_data/2858334303/build103084933/alignments/103084933_merged_rmdup.bam
	#-O gatk_testing/indels.GATK.H_GP-13-0890-01A-01-1.tsv -o gatk_testing/indels.GATK.H_GP-13-0890-01A-01-1.out 
	
	my $output_file = $self->output_file;
	my $cmd = join(" ", $path_to_gatk, $gatk_params, "-I", $self->bam_file, "-verbose", $output_file, "-o", $output_file.".vcf");

	## Optionally append BED output file ##

	my $bed_output_file = $self->output_file . ".bed";

	if($self->bed_output_file)
	{
		$bed_output_file = $self->bed_output_file;

	}

	$cmd .= " --bedOutput $bed_output_file";

	## Run GATK Command ##

	if($self->skip_if_output_present && -e $output_file)
	{
		
	}
	else
	{
		system("touch $output_file"); # This will create an empty output file to help prevent GATK from crashing 
		system("touch $bed_output_file"); # This will create an empty output file to help prevent GATK from crashing 
		system("touch $output_file.vcf"); # This will create an empty output file to help prevent GATK from crashing 
		my $return = Genome::Sys->shellcmd(
                           cmd => "$cmd",
                           output_files => [$output_file, "$output_file.vcf"],
                           skip_if_output_is_present => 0,
                       );
		unless($return) { 
			$self->error_message("Failed to execute GATK: GATK Returned $return");
			die $self->error_message;
		}
	}
	if($self->formatted_file)
	{
		my $formatted_output_file = $self->formatted_file;

		## Format GATK Indels ##

		if($self->skip_if_output_present && -e $formatted_output_file)
		{
			
		}
		else
		{
			print "Formatting indels for annotation...\n";
			
			my $cmd_obj = Genome::Model::Tools::Gatk::FormatIndels->create(
			    variants_file => $output_file,
			    output_file => $formatted_output_file,
			);
			
			$cmd_obj->execute;			
		}




	}

	return $return;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)

}



################################################################################################
# Parse_Somatic - isolate somatic indels 
#
################################################################################################

sub parse_somatic
{
	my $FileName = shift(@_);
	my $OutFileName = shift(@_);

	open(OUTFILE, ">$OutFileName") or die "Can't open outfile: $!\n";
	
	## Parse the variants file ##
	
	my $input = new FileHandle ($FileName);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		

		my @lineContents = split(/\t/, $line);
#		my $somatic_status = $lineContents[17];
		
		if(($lineContents[16] && $lineContents[16] =~ 'SOMATIC') || ($lineContents[17] && $lineContents[17] =~ 'SOMATIC'))
		{
			print OUTFILE "$line\n";
		}
		else
		{

		}
	}
	
	close($input);
	
	
	close(OUTFILE);


}

1;

