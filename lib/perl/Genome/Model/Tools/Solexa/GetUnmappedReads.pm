
package Genome::Model::Tools::Solexa::GetUnmappedReads;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# GetUnmappedReads.pm - 	Get unmapped/poorly-mapped reads by model id
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

class Genome::Model::Tools::Solexa::GetUnmappedReads {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		model_id	=> { is => 'Text', doc => "Genome model ID to retrieve reads" },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Retrieve maq-unplaced Solexa reads"                 
}

sub help_synopsis {
    return <<EOS
This command retrieves the locations of unplaced reads for a given genome model
EXAMPLE:	gmt solexa get-unmapped-reads --model-id 1235834
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
	my $model_id = $self->model_id;

	my @readsets = Genome::Model::InstrumentDataAssignment->get(model_id=>$model_id);

	if(@readsets)
	{
		foreach my $readset (@readsets)
		{
			my $dir = $readset->read_set_alignment_directory;
#			print "DIR: $dir\n";
			my $unaligned_file_for_lane = glob ("$dir/*unaligned*.fastq");
			if($unaligned_file_for_lane)
			{
				print "$unaligned_file_for_lane\n";				
			}

		}
		
		
	}
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

