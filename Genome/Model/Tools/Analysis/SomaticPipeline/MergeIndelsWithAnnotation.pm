
package Genome::Model::Tools::Analysis::SomaticPipeline::MergeIndelsWithAnnotation;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# MergeIndelsWithAnnotation - Merge glfSomatic/VarScan somatic calls in a file that can be converted to MAF format
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	10/23/2009 by D.K.
#	MODIFIED:	10/23/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;
use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Analysis::SomaticPipeline::MergeIndelsWithAnnotation {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		variants_file	=> { is => 'Text', doc => "File of variants in indel format", is_optional => 0 },
		annotation_file	=> { is => 'Text', doc => "Annotate-indel output file", is_optional => 0 },
		output_file     => { is => 'Text', doc => "Output file to receive merged data", is_optional => 0 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Merges indels with their annotations"                 
}

sub help_synopsis {
    return <<EOS
This command merges variant calls from the pipeline with their annotation information
EXAMPLE:	gt analysis somatic-pipeline merge-snvs-with-annotation --variants-file [file] --annotation-file [file] --output-file [file]
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
	my $annotation_file = $self->annotation_file;
	my $output_file = $self->output_file;
	
	## Load the annotations ##

	my %annotations = my %var_alleles = ();
	my $input = new FileHandle ($annotation_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		my @lineContents = split(/\t/, $line);
		my $chrom = $lineContents[0];
		my $chr_start = $lineContents[1];
		my $chr_stop = $lineContents[2];
		my $allele2 = $lineContents[3];
		$allele2 = $lineContents[4] if($lineContents[4]);
		my $variant_type = $lineContents[5];
		my $gene_name = $lineContents[6];
		my $transcript_name = $lineContents[7];
		my $trv_type = $lineContents[13];
		my $codon = $lineContents[14];
		my $aa_change = $lineContents[15];
		my $conservation = $lineContents[16];
		my $domain = $lineContents[17];

#		my $annotation = $variant_type . "\t" . $gene_name . "\t" . $transcript_name . "\t" . $trv_type . "\t" . $codon . "\t" . $aa_change . "\t" . $conservation;	
#		my $annotation = $lineContents[0] . "\t" . $lineContents[1] . "\t" . $lineContents[2] . "\t" . $lineContents[3] . "\t" . $lineContents[4] . "\t";
		my $annotation = $variant_type . "\t" . $gene_name . "\t" . $transcript_name . "\t" . $trv_type . "\t" . $codon . "\t" . $aa_change . "\t" . $domain; #$conservation;	

		my $variant_key = $chrom . "\t" . $chr_start; # . "\t" . $variant_type; #. "\t" . $allele1 . "\t" . $allele2
		$annotations{$variant_key} = $annotation;

		$variant_key = $chrom . "\t" . $chr_stop; # . "\t" . $variant_type; #. "\t" . $allele1 . "\t" . $allele2
		$annotations{$variant_key} = $annotation;

		$var_alleles{$variant_key} = $allele2;
	}

	close($input);
	
	
	## Open outfile ##
	
	open(OUTFILE, ">$output_file") or die "Can't open outfile: $!\n";
	
	## Parse the variants file ##
	
	$input = new FileHandle ($variants_file);
	$lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;

		my @lineContents = split(/\t/, $line);
		my $numContents = @lineContents;
		my $chrom = $lineContents[0];
		my $chr_start = $lineContents[1];
		my $chr_stop = $lineContents[2];
		my $reference = $lineContents[3];
		my $variant = $lineContents[4];
		my $somatic_score = $lineContents[6];
		my $tumor_reads1 = $lineContents[12];
		my $tumor_reads2 = $lineContents[13];
		my $normal_reads1 = $lineContents[26]; # number of reads that support indel 1 in normal
		my $normal_reads2 = $lineContents[27]; # number of reads that support indel 2 in normal 
		my $tumor_coverage = $tumor_reads1 + $tumor_reads2;
		my $tumor_freq = ($tumor_reads2) / ($tumor_reads1 + $tumor_reads2);
		
		#my $coverage = $lineContents[11];
#		my $reads1 = $lineContents[12];
#		my $reads2 = $lineContents[13];
		
		## Determine rest of line ##
		my $rest_of_line = "";
		for(my $colCounter = 2; $colCounter < $numContents; $colCounter++)
		{
			$rest_of_line .= "\t" . $lineContents[$colCounter];
		}

		my $variant_key = $chrom . "\t" . $chr_start;# . "\t" . $indel_type; #. "\t" . $allele1 . "\t" . $allele2

		if(!$annotations{$variant_key})
		{
			$variant_key = $chrom . "\t" . ($chr_start + 1);# . "\t" . $indel_type; #. "\t" . $allele1 . "\t" . $allele2
		}

		## Get the annotation ##
		
#		my $annotation = $lineContents[0] . "\t" . $lineContents[1] . "\t" . $lineContents[2] . "\t" . $lineContents[3] . "\t" . $lineContents[4] . "\t" . $lineContents[5] . "\t" . "-\t-\t-\t-\t-\t-\t-";
		if($annotations{$variant_key})
		{
			my $annotation = $annotations{$variant_key};
			print OUTFILE "$chrom\t$chr_start\t$chr_stop\t$reference\t$variant\t$annotation\t$somatic_score\t$tumor_coverage\t$tumor_freq\n";
		}
		
#		print OUTFILE $chrom . "\t" . $chr_start . "\t" . $allele1 . "\t" . $allele2 . "\t" . $indel_type . "\t" . $annotation . "\n";

	}

	close($input);
		
	close(OUTFILE);
}





1;

