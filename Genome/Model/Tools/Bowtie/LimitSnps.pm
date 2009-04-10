
package Genome::Model::Tools::Bowtie::LimitSnps;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# LimiSnps.pm - 	Limit SNPs by various factors, like ROI positions.
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	03/20/2009 by D.K.
#	MODIFIED:	03/20/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Bowtie::LimitSnps {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		variants_file	=> { is => 'Text', doc => "File containing SNPs" },
		positions_file	=> { is => 'Text', doc => "File containing ROI chromosome positions (chr1\t939339)"},
		output_file	=> { is => 'Text', doc => "Output file to receive limited SNPs", is_optional => 1 },
		not_file	=> { is => 'Text', doc => "Output file to receive excluded SNPs", is_optional => 1 },
		verbose	=> { is => 'Text', doc => "Print interim progress updates", is_optional => 1 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Parse output from the Bowtie aligner"                 
}

sub help_synopsis {
    return <<EOS
This command parses alignments from Bowtie.
EXAMPLE:	gt bowtie parse-alignments --alignments-file bowtie.txt
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
	my $variants_file = $self->variants_file;
        my $positions_file = $self->positions_file;
	my $notfile = $self->not_file if(defined($self->not_file));
	my $outfile = $self->output_file if(defined($self->output_file));
	my $verbose = 1 if(defined($self->verbose));

        if(!$positions_file || !(-e $positions_file))
        {
                die "\n***Positions file not found!\n";
        }

        if(!$variants_file || !(-e $variants_file))
        {
                die "\n***Variants file not found!\n";
        }

	my %stats = ();
	$stats{'total_snps'} = $stats{'limit_snps'} = 0;
	my $input, my $lineCounter;

	print "Parsing ROI positions...\n";

	my %roi_positions = ();

	if($positions_file)
	{
		## Parse the alignment blocks ##
	
		$input = new FileHandle ($positions_file);
		$lineCounter = 0;
		
		while (<$input>)
		{
			chomp;
			my $line = $_;
			$lineCounter++;
			
			if($lineCounter >= 1)# && $lineCounter < 50000)
			{
				(my $chrom, my $position) = split(/\t/, $line);
				$roi_positions{$chrom . "\t" . $position} = 1;
			}
		}
		
		close($input);
		
		print "$lineCounter positions loaded\n";
	}

	print "Parsing SNPs...\n";
	## Parse the combined SNPs ##

	## Open the outfile ##
	if($outfile)
	{
		open(OUTFILE, ">$outfile") or die "Can't open outfile: $!\n";
	}
	
	if($notfile)
	{
		open(NOTFILE, ">$notfile") or die "Can't open outfile: $!\n";
	}

	$input = new FileHandle ($variants_file);
	$lineCounter = 0;
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		if($lineCounter == 1)
		{
			print OUTFILE "$line\n" if($outfile);
			print NOTFILE "$line\n" if($notfile);
		}
		if($lineCounter > 1)# && $lineCounter < 1000)
		{
			$stats{'total_snps'}++;
#			(my $chrom, my $position, my $allele1, my $allele2, my $context, my $num_reads, my $reads) = split(/\t/, $line);			
			(my $chrom, my $position) = split(/\t/, $line);

			my $included_flag = 0;
			
			if(!$positions_file || $roi_positions{$chrom . "\t" . $position})
			{
				$stats{'limit_snps'}++;
				print OUTFILE "$line\n" if($outfile);
				$included_flag = 1;
			}
			
			if(!$included_flag)
			{
				print NOTFILE "$line\n" if($notfile);
			}
		}
	}

	close($input);
	
	close(OUTFILE) if($outfile);
	close(NOTFILE) if($notfile);

	print "$stats{'total_snps'} total SNPs\n";

	## Get percentage ##
	
        if($stats{'total_snps'})
        {
        	$stats{'limit_pct'} = sprintf("%.2f", ($stats{'limit_snps'} / $stats{'total_snps'} * 100)) . '%';
        	print "$stats{'limit_snps'} SNPs ($stats{'limit_pct'}) remained after filter\n";
        }



	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

