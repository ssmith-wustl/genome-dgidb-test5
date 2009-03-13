
package Genome::Model::Tools::Bowtie::GetReadcounts;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# GetReadcounts.pm - 	Get unmapped/poorly-mapped reads by model id
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

class Genome::Model::Tools::Bowtie::GetReadcounts {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		variants_file	=> { is => 'Text', doc => "File containing combined Bowtie SNPs" },
		blocks_file	=> { is => 'Text', doc => "File containing Bowtie alignment blocks" },
		output_file	=> { is => 'Text', doc => "File to receive combined SNPs" },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Parse output from Bowtie"                 
}

sub help_synopsis {
    return <<EOS
This command retrieves the locations of unplaced reads for a given genome model
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
        my $blocks_file = $self->blocks_file;
	my $outfile = $self->output_file;


	my %GenotypeStats = ();
	my %VariantRegions = my %SNPsByPosition = my %CoverageByPosition = ();
	
	print "Parsing SNPs...\n";
	## Parse the combined SNPs ##

	my $input = new FileHandle ($variants_file);
	my $lineCounter = 0;
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		if($lineCounter > 1)# && $lineCounter < 1000)
		{
#			(my $chrom, my $position, my $allele1, my $allele2, my $context, my $num_reads, my $reads) = split(/\t/, $line);			
			(my $chrom, my $position, my $allele1, my $allele2, my $num_reads, my $avg_qual, my $num_strands) = split(/\t/, $line);

                        if($num_reads >= 10 && $avg_qual >= 20)
                        {
                                my $position_key = $chrom . ":" . $position; #substr($position, 0, 2);
                                $SNPsByPosition{$position_key} += $num_reads;
                                
                                ## Build a key using chromosome and first 2 bases of position for storing this SNP ##
                                my $chrom_key = $chrom . ":" . substr($position, 0, 2);
                                $VariantRegions{$chrom_key}++;			
                                
                               $GenotypeStats{'num_snps'}++;
                        }
		}
	}

	close($input);

	print $GenotypeStats{'num_snps'} . " SNPs loaded\n";



	print "Parsing alignment blocks...\n";

	## Parse the alignment blocks ##

	$input = new FileHandle ($blocks_file);
	$lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		if($lineCounter > 1)# && $lineCounter < 50000)
		{
			$GenotypeStats{'total_alignments'}++;
			print "$GenotypeStats{'total_alignments'} alignments\n" if(!($GenotypeStats{'total_alignments'} % 1000));
		
			my @lineContents = split(/\s+/, $line);
			my $chrom = $lineContents[0];
			my $chr_start = $lineContents[1];
			my $chr_stop = $lineContents[2];
			my $strand = $lineContents[3];
			my $read_name = $lineContents[4];
	
			
			## Get possible chrom position keys ##
                        my $position_key;
                        
                        for(my $position = $chr_start; $position <= $chr_stop; $position++)
                        {
                                $position_key = $chrom . ":" . $position; #substr($position, 0, 2);
                                if($SNPsByPosition{$position_key})
                                {
                                        $CoverageByPosition{$position_key}++;
                                }
                        }
		

		}
	}
	
	close($input);

        my $keyCount = 0;
        foreach my $key (keys %CoverageByPosition)
        {
                $keyCount++;
        }
        
        print "$keyCount keys had coverage\n";

	## Open the outfile ##
	
	open(OUTFILE, ">$outfile") or die "Can't open outfile: $!\n";
	print OUTFILE "chrom\tposition\tref\tvar\tcov\treads1\treads2\tavgQual\tstrands\n";

	print "Parsing SNPs again...\n";

	$input = new FileHandle ($variants_file);
	$lineCounter = 0;
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		
		if($lineCounter == 1)
		{
		}
		if($lineCounter > 1)# && $lineCounter < 1000)
		{
			(my $chrom, my $position, my $allele1, my $allele2, my $num_reads, my $avg_qual, my $num_strands) = split(/\t/, $line);
			my $position_key = $chrom . ":" . $position; #substr($position, 0, 2);

                        if($num_reads >= 10 && $avg_qual >= 20 && $CoverageByPosition{$position_key})
                        {
                                my $read_coverage = $CoverageByPosition{$position_key};
                                ## Calculate $reads1 ##
                                my $num_wt_reads = $CoverageByPosition{$position_key} - $SNPsByPosition{$position_key};
                                
                                if($num_wt_reads < 0)
                                {
#                                        print "Warning: Reads1 calculated to be less than zero: $line\n";
 #                                       exit(1);
                                }
                                else
                                {
                                        print OUTFILE "$chrom\t$position\t$allele1\t$allele2\t$read_coverage\t$num_wt_reads\t$num_reads\t$avg_qual\t$num_strands\n";			
                                }
                        }
		}
	}

	close($input);

	close(OUTFILE);


	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

