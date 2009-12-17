
package Genome::Model::Tools::Capture::BuildModels;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# BuildModels - Build Genome Models for Capture Datasets
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

class Genome::Model::Tools::Capture::BuildModels {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		model_basename	=> { is => 'Text', doc => "Project string for model naming, e.g. \"TCGA-OV-6K-Capture-bwa\"", is_optional => 0 },
		processing_profile	=> { is => 'Text', doc => "Processing profile to use, e.g. \"bwa0.5.5 and samtools r510 and picard r107\"", is_optional => 0 },
		sample_list	=> { is => 'Text', doc => "Text file with sample names to include, one per line" , is_optional => 0},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Create and build genome models for capture datasets"                 
}

sub help_synopsis {
    return <<EOS
Create and build genome models for capture datasets
EXAMPLE:	gt capture build-models ...
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
	my $processing_profile = $self->processing_profile;
	my $model_basename = $self->model_basename;
	my $sample_list = $self->sample_list;

	
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

