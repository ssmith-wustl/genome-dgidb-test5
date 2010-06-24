
package Genome::Model::Tools::Capture::WiggleFromPileup;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# WiggleFromQ20 - Converts a pileup file to a three column file of chromosome, position, and bases with q>20.
#					
#	AUTHOR:		Will Schierding
#
#	CREATED:	06/24/2010 by W.S.
#	MODIFIED:	06/24/2010 by W.S.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;
use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Capture::WiggleFromPileup {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		normal_bam	=> { is => 'Text', doc => "Normal Bam File", is_optional => 0, is_input => 1 },
		tumor_bam	=> { is => 'Text', doc => "Tumor Bam File", is_optional => 0, is_input => 1 },
		reference_fasta	=> { is => 'Text', doc => "Reference Genome", is_optional => 1, is_input => 1, default =>"/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa"},
		regions_file	=> { is => 'Text', doc => "Tab-delimited list of regions", is_optional => 0, is_input => 1 },
		min_depth_normal	=> { is => 'Text', doc => "Minimum Q20 depth for Normal [6]", is_optional => 1, is_input => 1, default => 6 },
		min_depth_tumor	=> { is => 'Text', doc => "Minimum Q20 depth for Tumor [8]", is_optional => 1, is_input => 1, default => 8 },
		output_file     => { is => 'Text', doc => "Output file to receive per-base qual>min coverage", is_optional => 0, is_input => 1, is_output => 1 },
		gzip_after	=> { is => 'Text', doc => "If set to 1, compress the file after building", is_optional => 1, is_input => 1, default => 0 },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Input bam files, builds a wiggle coverage file for a list of ROIs"
}

sub help_synopsis {
    return <<EOS
Builds a wiggle coverage file for a list of ROIs - Takes in two bam files, calls samtools pileup, creates Q20, then converts to wiggle
EXAMPLE:	gmt capture wiggle-from-pileup --normal-bam [normal bam file] --tumor-bam [tumor bam file] --regions-file [targets.tsv] --output-file [patient.wiggle]
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 
    Takes in two bam files, calls samtools pileup, creates Q20, then converts to wiggle coverage file for a list of ROIs                 
EOS
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
	my $self = shift;
	#bam files
	my $normal_bam = $self->normal_bam;
	my $tumor_bam = $self->tumor_bam;
	# reference genome for samtools pileup
	my $bam_ref = $self->reference_fasta;

	#Call Samtools pileup for normal
	my $out_normal = ">temppileup_normal.txt";
	my $cmd1 = "samtools pileup -f $bam_ref $normal_bam $out_normal";
	#system ($cmd1);
	#Call Samtools pileup for tumor
	my $out_tumor = ">temppileup_tumor.txt";
	my $cmd2 = "samtools pileup -f $bam_ref $tumor_bam $out_tumor";
	#system ($cmd2);

	#set coverage at q20
	my $min_base_qual = 20;
	my $min_coverage = 0;
	
	my $q20_normal_file = 'q20_coverage_normal.txt';
	my $q20_tumor_file = 'q20_coverage_tumor.txt';
	# Open Output
	unless (open(NORMAL_Q20,">$q20_normal_file")) {
		die "Could not open output file '$q20_normal_file' for writing";
	  }
	# Open Output
	unless (open(TUMOR_Q20,">$q20_tumor_file")) {
		die "Could not open output file '$q20_tumor_file' for writing";
	  }

	my $lineCounter_normal = 0;
	my $lineCounter_tumor = 0;
	my %normal_coverage = ();
	my %tumor_coverage = ();
	print "Loading normal coverage...\n";
	my $input1 = new FileHandle ($out_normal);
	while (<$input1>) {
		chomp;
		my $line = $_;
		$lineCounter_normal++;		
	
		my @lineContents = split(/\t/, $line);			
		my $chrom = $lineContents[0];
		my $position = $lineContents[1];
		my $ref_base = $lineContents[2];
		my $depth = $lineContents[3];
		my $qualities = $lineContents[5];

		## Go through each quality ##
		
		my @qualities = split(//, $qualities);
		my $num_quals = 0;
		my $qual_coverage = 0;
		
		foreach my $code (@qualities) {
			my $qual_score = ord($code) - 33;
			$num_quals++;

			if($qual_score >= $min_base_qual)
			{
				$qual_coverage++;
			}
		}
		
		if($qual_coverage >= $min_coverage) {
			print NORMAL_Q20 "$chrom\t$position\t$qual_coverage\n";			
			my $wiggle_chr = $chrom;
			$wiggle_chr =~ s/chr//;
			$wiggle_chr = "MT" if($chrom eq "M");
			my $key = "$wiggle_chr\t$position";
			$normal_coverage{$key} = $qual_coverage;
		}
	}

	close($input1);

	print "Loading tumor coverage...\n";
	my $input2 = new FileHandle ($out_tumor);
	while (<$input2>) {
		chomp;
		my $line = $_;
		$lineCounter_tumor++;		
	
		my @lineContents = split(/\t/, $line);			
		my $chrom = $lineContents[0];
		my $position = $lineContents[1];
		my $ref_base = $lineContents[2];
		my $depth = $lineContents[3];
		my $qualities = $lineContents[5];

		## Go through each quality ##
		
		my @qualities = split(//, $qualities);
		my $num_quals = 0;
		my $qual_coverage = 0;
		
		foreach my $code (@qualities) {
			my $qual_score = ord($code) - 33;
			$num_quals++;

			if($qual_score >= $min_base_qual)
			{
				$qual_coverage++;
			}
		}
		
		if($qual_coverage >= $min_coverage) {
			print TUMOR_Q20 "$chrom\t$position\t$qual_coverage\n";			
			my $wiggle_chr = $chrom;
			$wiggle_chr =~ s/chr//;
			$wiggle_chr = "MT" if($chrom eq "M");
			my $key = "$wiggle_chr\t$position";
			$tumor_coverage{$key} = $qual_coverage;
		}
	}
	close($input2);

	## Get required parameters ##
	my $regions_file = $self->regions_file;
	my $output_file = $self->output_file;
	my $min_depth_normal = $self->min_depth_normal;
	my $min_depth_tumor = $self->min_depth_tumor;
		
	print "Parsing regions file...\n";	

	## Open outfile ##
	
	open(OUTFILE, ">$output_file") or die "Can't open outfile: $!\n";
	
	my %stats = ();
	$stats{'bases'} = $stats{'covered'} = $stats{'not_covered'} = 0;
	
	## Parse the regions ##

	my $input = new FileHandle ($regions_file);
	my $lineCounter = 0;

	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		

		(my $chrom, my $chr_start, my $chr_stop, my $region_name) = split(/\t/, $line);

		## Print wiggle header ##
		print OUTFILE "fixedStep chrom=chr$chrom start=$chr_start step=1\n";			

		for(my $position = $chr_start; $position <= $chr_stop; $position++)
		{
			my $key = "$chrom\t$position";
			$stats{'bases'}++;

			## Determine if coverage is met ##
			
			if($normal_coverage{$key} && $tumor_coverage{$key} && $normal_coverage{$key} >= $min_depth_normal && $tumor_coverage{$key} >= $min_depth_tumor)
			{				
				print OUTFILE "1\n";
				$stats{'covered'}++;
			}
			else
			{
				print OUTFILE "0\n";
				$stats{'not_covered'}++;
			}
		}
	}

	close($input);


	close(OUTFILE);

	print $stats{'bases'} . " bases in ROI\n";
	print $stats{'covered'} . " bases covered >= " . $min_depth_normal . "x in normal and >= " . $min_depth_tumor . "x in tumor\n";
	print $stats{'not_covered'} . " bases NOT covered >= " . $min_depth_normal . "x in normal and >= " . $min_depth_tumor . "x in tumor\n";

	if($self->gzip_after)
	{
		print "Compressing $output_file...\n";
		system("gzip $output_file"); 
	}
	
	return 1;
}




1;

