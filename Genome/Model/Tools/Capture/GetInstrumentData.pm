
package Genome::Model::Tools::Capture::GetInstrumentData;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# GetInstrumentData - Get Instrument Data for Capture Samples
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

## Declare global statistics hash ##

my %stats = ();
my $search_string = "bwa0_5_5";

class Genome::Model::Tools::Capture::GetInstrumentData {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		sample_list	=> { is => 'Text', doc => "Text file with sample names to include, one per line" , is_optional => 0},
		search_string 	=> { is => 'Text', doc => "String used in alignment output directory naming [bwa0_5_5]", is_optional => 1}
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Get Instrument Data for samples in a capture set"                 
}

sub help_synopsis {
    return <<EOS
Get Instrument Data for samples in a capture set
EXAMPLE:	gmt capture get-instrument-data ...
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
	my $sample_list = $self->sample_list;
	
	$search_string = $self->search_string if($self->search_string);

	## Reset statistics ##
	$stats{'num_samples'} = 0;

	my $input = new FileHandle ($sample_list);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		(my $sample_name) = split(/\t/, $line);
		$stats{'num_samples'}++;

		print "$sample_name\n";
		get_instrument_data($sample_name);

	}

	close($input);
	
	## Print summary report ##
	
	print $stats{'num_samples'} . " samples in file\n";
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}




#############################################################
# ParseFile - takes input file and parses it
#
#############################################################

sub get_instrument_data
{
	my $sample_name = shift(@_);

	my $data_output = `genome instrument-data list solexa --noheaders 1 --filter=sample_name=$sample_name --show=id,flow_cell_id,lane,clusters,read_length 2>/dev/null`;
	chomp($data_output);
	my @output_lines = split(/\n/, $data_output);
	
	foreach my $line (@output_lines)
	{
		(my $data_id) = split(/\s+/, $line);
		my $alignment_location = get_alignment_allocation($data_id);
		print "$line\t$alignment_location\n";
	}

}



#############################################################
# ParseFile - takes input file and parses it
#
#############################################################

sub get_alignment_allocation
{
	my $data_id = shift(@_);

	my $data_output = `genome disk allocation list --filter=owner_id=$data_id 2>/dev/null`;
	chomp($data_output);
	my @output_lines = split(/\n/, $data_output);
	my $alignment_dir = "";
	my $alignment_file = "";

	foreach my $line (@output_lines)
	{
		($alignment_dir) = split(/\s+/, $line);

		if(!$alignment_file || $alignment_dir =~ $search_string)
		{
			if($alignment_dir && -d $alignment_dir)
			{
				$alignment_file = $alignment_dir . "/all_sequences.bam";
		
			}			
		}
	}

	return($alignment_file);




}




1;

