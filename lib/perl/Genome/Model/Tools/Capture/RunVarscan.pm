
package Genome::Model::Tools::Capture::RunVarscan;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# RunVarscan - Run VarScan somatic on two BAM files.
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	12/09/2009 by D.K.
#	MODIFIED:	12/09/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Capture::RunVarscan {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		normal_bam	=> { is => 'Text', doc => "Path to Normal BAM file", is_optional => 0 },
		tumor_bam	=> { is => 'Text', doc => "Path to Tumor BAM file", is_optional => 0 },
		output	=> { is => 'Text', doc => "Basename for output, eg. varscan_out/varscan.status" , is_optional => 0},
		reference	=> { is => 'Text', doc => "Reference FASTA file for BAMs (default= genome model)" , is_optional => 1},
		heap_space	=> { is => 'Text', doc => "Megabytes to reserve for java heap [1000]" , is_optional => 1},
		varscan_params	=> { is => 'Text', doc => "Parameters to pass to VarScan [--min-coverage 8 --min-var-freq 0.10 --p-value 0.10 --somatic-p-value 1.0e-02]" , is_optional => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Create and build genome models for capture datasets"                 
}

sub help_synopsis {
    return <<EOS
Runs VarScan from BAM files
EXAMPLE:	gmt capture run-varscan ...
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
	my $tumor_bam = $self->tumor_bam;
	my $output = $self->output;
	my $reference = Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fa';
	$reference = $self->reference if($self->reference);
	my $varscan_params = "--min-coverage 8 --min-var-freq 0.10 --p-value 0.10 --somatic-p-value 0.01 --verbose 1";

	if(-e $normal_bam && -e $tumor_bam)
	{
		## Prepare pileup commands ##
		
		my $normal_pileup = "samtools pileup -f $reference $normal_bam";
		my $tumor_pileup = "samtools pileup -f $reference $tumor_bam";
		
		open(SCRIPT, ">$output.sh") or die "Can't open output file!\n";
		print SCRIPT "#!/gsc/bin/bash\n";
		## Run VarScan ##
		if($self->heap_space)
		{
#			system("java -Xms" . $self->heap_space . "m -Xmx" . $self->heap_space . "m -classpath ~dkoboldt/Software/VarScan net.sf.varscan.VarScan somatic <($normal_pileup) <($tumor_pileup) $output $varscan_params");						
		}
		else
		{
			print SCRIPT "java -classpath ~dkoboldt/Software/VarScan net.sf.varscan.VarScan somatic <\($normal_pileup\) <\($tumor_pileup\) $output $varscan_params\n";
#			system("echo  \<\($normal_pileup\) \<\($tumor_pileup\) $output $varscan_params");
		}
		close(SCRIPT);
		system("chmod 755 $output.sh");
		system("bash $output.sh");
	}
	else
	{
		die "Error: One of your BAM files doesn't exist!\n";
	}
	
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

