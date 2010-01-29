
package Genome::Model::Tools::Varscan::Germline;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# Varscan::Germline	Runs VarScan to call and filter SNPs/indels
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	12/09/2009 by D.K.
#	MODIFIED:	12/29/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Varscan::Germline {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		normal_bam	=> { is => 'Text', doc => "Path to Normal BAM file", is_optional => 0, is_input => 1 },
		output_snp	=> { is => 'Text', doc => "Basename for SNP output, eg. varscan.snp" , is_optional => 0, is_input => 1, is_output => 1},
		output_indel	=> { is => 'Text', doc => "Basename for indel output, eg. varscan.indel" , is_optional => 0, is_input => 1, is_output => 1},
		reference	=> { is => 'Text', doc => "Reference FASTA file for BAMs (default= genome model)" , is_optional => 1, is_input => 1},
		heap_space	=> { is => 'Text', doc => "Megabytes to reserve for java heap [1000]" , is_optional => 1, is_input => 1},
		varscan_params	=> { is => 'Text', doc => "Parameters to pass to VarScan [--min-coverage 8 --min-var-freq 0.10 --p-value 0.05]" , is_optional => 1, is_input => 1},
	],	

	has_param => [
		lsf_resource => { default_value => 'select[model!=Opteron250 && type==LINUX64 && mem>4000] rusage[mem=4000]', doc => "LSF resource requirements [default: 64-bit, 4 GB RAM]", is_optional => 1},
       ],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Run the VarScan germline variant detection"                 
}

sub help_synopsis {
    return <<EOS
Runs VarScan from BAM files
EXAMPLE:	gmt varscan germline --normal-bam [Normal.bam]  ...
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
	my $normal_bam = $self->normal_bam;
	my $output_snp = $self->output_snp;
	my $output_indel = $self->output_indel;

	## Get reference ##

	my $reference = "/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa";
	$reference = $self->reference if($self->reference);

	## Get VarScan parameters ##

	my $varscan_params = "--min-var-freq 0.10 --p-value 0.10 --somatic-p-value 0.01"; #--min-coverage 8 --verbose 1
	$varscan_params = $self->varscan_params if($self->varscan_params);

	my $path_to_varscan = "java -classpath ~dkoboldt/Software/VarScan net.sf.varscan.VarScan";
	$path_to_varscan = "java -Xms" . $self->heap_space . "m -Xmx" . $self->heap_space . "m -classpath ~dkoboldt/Software/VarScan net.sf.varscan.VarScan" if($self->heap_space);

	if(-e $normal_bam)
	{
		## Prepare pileup commands ##
		
		my $normal_pileup = "samtools pileup -f $reference $normal_bam";
		
		## Run VarScan ##

		my $cmd = "";

		## Call SNPs ##
		$cmd = "bash -c \"$path_to_varscan pileup2snp <\($normal_pileup\) $varscan_params >$output_snp\"";
		print "RUN: $cmd\n";
		system($cmd);

		## Call Indels ##
		$cmd = "bash -c \"$path_to_varscan pileup2indel <\($normal_pileup\) $varscan_params >$output_indel\"";
		print "RUN: $cmd\n";
		system($cmd);

		## Filter SNPs using Indels ##
		if(-e $output_snp && $output_indel)
		{
			$cmd = "bash -c \"$path_to_varscan filter $output_snp $varscan_params --indel-file $output_indel >$output_snp.filter\"";
			print "RUN: $cmd\n";
			system($cmd);
		}
	}
	else
	{
		die "Error: One of your BAM files doesn't exist!\n";
	}
	
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}


1;

