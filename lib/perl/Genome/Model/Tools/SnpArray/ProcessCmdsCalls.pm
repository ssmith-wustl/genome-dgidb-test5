
package Genome::Model::Tools::SnpArray::ProcessCmdsCalls;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# SearchRuns - Search the database for runs
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	04/01/2009 by D.K.
#	MODIFIED:	04/01/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

my %stats = ();

class Genome::Model::Tools::SnpArray::ProcessCmdsCalls {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		map_file	=> { is => 'Text', doc => "Three-column file of genotype calls chrom, pos, genotype", is_optional => 0, is_input => 1 },
		cmds_file	=> { is => 'Text', doc => "Three-column file of genotype calls chrom, pos, genotype", is_optional => 0, is_input => 1 },
		output_basename	=> { is => 'Text', doc => "Output file for QC result", is_optional => 1, is_input => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Merges CMDS calls with map file and generates per-chromosome data"                 
}

sub help_synopsis {
    return <<EOS
This command merges CMDS calls with map file and generates per-chromosome data
EXAMPLE:	gmt snp-array process-cmds-calls --map-file /gscmnt/sata181/info/medseq/llin/Ovarian/SNP/CMDS_444_samples/map.csv --cmds-file /gscmnt/sata181/info/medseq/llin/Ovarian/SNP/CMDS_444_samples/NORMALIZATION/TCGA-10-0933.csv
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
	my $map_file = $self->map_file;
	my $cmds_file = $self->cmds_file;
	my $output_basename = $self->output_basename;

	## Load the map file ##
	print "Loading map file and opening outfiles...\n";

	my $input = new FileHandle ($map_file);
	my @map_lines = ();
	my $lineCounter = 0;
	my %file_handles = ();

	while (<$input>)
	{
		chomp;
		my $line = $_;
		my ($snp, $chrom, $position) = split(/\t/, $line);
		
		if($chrom ne "CHR" && !$file_handles{$chrom})
		{
			open($file_handles{$chrom}, ">$output_basename.$chrom.tsv") or die "Can't open outfile: $!\n";
		}
		
		$lineCounter++;
		$map_lines[$lineCounter] = $line;
	}
	close($input);

	print "$lineCounter lines loaded\n";


	## Parse the CMDS values file ##

	## Load the map file ##
	print "Parsing CMDS file...\n";

	$input = new FileHandle ($cmds_file);
	$lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		## Skip header ##

		if($lineCounter > 1)
		{
			if($map_lines[$lineCounter])
			{
				my $log2 = $line;
				my ($snp, $chrom, $position) = split(/\t/, $map_lines[$lineCounter]);
				if($file_handles{$chrom})
				{
					my $outfile = $file_handles{$chrom};
					print $outfile "$chrom\t$position\t$log2\n";					
				}

			}
			else
			{
				die "No map result for line $lineCounter; make sure $map_file is same length as $cmds_file\n";
			}			
		}


	}
	close($input);


	## Close output file ##
	
	foreach my $chrom (sort keys %file_handles)
	{
		close($file_handles{$chrom}) if($file_handles{$chrom});
	}


}

###############################################################################
# commify - add appropriate commas to long integers
###############################################################################

sub commify
{
	local($_) = shift;
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}


1;

