
package Genome::Model::Tools::Bowtie::CombineVariants;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# CombineVariants.pm - 	Get unmapped/poorly-mapped reads by model id
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

class Genome::Model::Tools::Bowtie::CombineVariants {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		variants_file	=> { is => 'Text', doc => "File containing Bowtie SNPs" },
		output_file	=> { is => 'Text', doc => "File to receive combined SNPs" },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Combine variants detected in Bowtie alignments"                 
}

sub help_synopsis {
    return <<EOS
This command retrieves the locations of unplaced reads for a given genome model
EXAMPLE:	gmt bowtie parse-alignments --alignments-file bowtie.txt
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
	my $infile = $self->variants_file;
	my $outfile = $self->output_file;

	my %SNPcontexts = my %NumReads = my %SupportingStrands = my %VariantAlleles = ();
	
	my %SNPqualitySum = ();
	
	my %CombineStats = ();
	$CombineStats{'snp_events'} = 0;
	$CombineStats{'unique_snps'} = 0;
	
	
	## Open the input file ##
	
	my $input = new FileHandle ($infile);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;
		

		if($lineCounter > 1)
		{
			(my $chrom, my $position, my $allele1, my $allele2, my $read_name, my $read_pos, my $align_strand, my $base_qual_score) = split(/\t/, $line);

                        $base_qual_score = 15 if(!$base_qual_score);
		
			my $snp_key = "$chrom\t$position\t$allele1\t$allele2";		
		
			if($allele2 =~ /[ACGT]/)
			{
				$CombineStats{'snp_events'}++;
				$NumReads{$snp_key}++;
			
                                $SNPqualitySum{$snp_key} = 0 if(!$SNPqualitySum{$snp_key});
				$SNPqualitySum{$snp_key} += $base_qual_score;

				$VariantAlleles{$snp_key} = "" if(!$VariantAlleles{$snp_key});
                                $SupportingStrands{$snp_key} = "" if(!$SupportingStrands{$snp_key});
                                
                                if(!$SupportingStrands{$snp_key} || (length($SupportingStrands{$snp_key}) < 2 && substr($SupportingStrands{$snp_key}, 0, 1) ne $align_strand))
                                {
                                        $SupportingStrands{$snp_key} .= $align_strand;
                                }
                                
				if(!($VariantAlleles{$snp_key} =~ $allele2))
				{
					$VariantAlleles{$snp_key} .= "/" if($VariantAlleles{$snp_key});					
					$VariantAlleles{$snp_key} .= $allele2 
				}
			}

		}
	}
	
	open(OUTFILE, ">$outfile") or die "Can't open outfile: $!\n";
	print OUTFILE "chrom\tposition\tref\tvar\treads2\tavgQual\tstrands\n";	
	foreach my $snp_key (sort keys %VariantAlleles)
	{
		$CombineStats{'unique_snps'}++;
		## Determine average base quality ##
		my $avg_base_qual = $SNPqualitySum{$snp_key} / $NumReads{$snp_key};
		$avg_base_qual = sprintf("%d", $avg_base_qual);
		my $num_reads = $NumReads{$snp_key};

                my $num_strands = length($SupportingStrands{$snp_key});            

		print OUTFILE "$snp_key\t$num_reads\t$avg_base_qual\t$num_strands\n";
	}
	close(OUTFILE);


	print "$CombineStats{'snp_events'} substitution events\n";
	print "$CombineStats{'unique_snps'} unique SNPs\n";
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}



1;

