
package Genome::Model::Tools::Varscan::CopyNumber;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# Varscan::Somatic	Runs VarScan somatic pipeline on Normal/Tumor BAM files
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#	CREATED:	12/09/2009 by D.K.
#	MODIFIED:	12/29/2009 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Varscan::CopyNumber {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		normal_bam	=> { is => 'Text', doc => "Path to Normal BAM file", is_optional => 0, is_input => 1 },
		tumor_bam	=> { is => 'Text', doc => "Path to Tumor BAM file", is_optional => 0, is_input => 1 },
		output	=> { is => 'Text', doc => "Path to Tumor BAM file", is_optional => 1, is_input => 1, is_output => 1 },
		output_snp	=> { is => 'Text', doc => "Basename for SNP output, eg. varscan_out/varscan.status.snp" , is_optional => 1, is_input => 1, is_output => 1},
		output_indel	=> { is => 'Text', doc => "Basename for indel output, eg. varscan_out/varscan.status.snp" , is_optional => 1, is_input => 1, is_output => 1},
		reference	=> { is => 'Text', doc => "Reference FASTA file for BAMs (default= genome model)" , is_optional => 1, is_input => 1},
		heap_space	=> { is => 'Text', doc => "Megabytes to reserve for java heap [1000]" , is_optional => 1, is_input => 1},
		mapping_quality	=> { is => 'Text', doc => "Default minimum mapping quality" , is_optional => 1, is_input => 1, default => 10},
		skip_if_output_present	=> { is => 'Text', doc => "If set to 1, skip execution if output files exist", is_optional => 1, is_input => 1 },
		varscan_params	=> { is => 'Text', doc => "Parameters to pass to VarScan [--min-coverage 8 --min-var-freq 0.08 --p-value 0.10 --somatic-p-value 0.05 --strand-filter 1]" , is_optional => 1, is_input => 1},
	],	

	has_param => [
		lsf_resource => { default_value => 'select[model!=Opteron250 && type==LINUX64] rusage[mem=4000]'},
       ],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Run the VarScan somatic variant detection"                 
}

sub help_synopsis {
    return <<EOS
Runs VarScan from BAM files
EXAMPLE:	gmt varscan somatic --normal-bam [Normal.bam] --tumor-bam [Tumor.bam] --output varscan_out/Patient.status ...
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
	my $min_map_qual = $self->mapping_quality;

	## Get output directive ##
	my $output = my $output_snp = my $output_indel = "";

	if($self->output)
	{
		$output = $self->output;
		$output_snp = $output . ".snp";
		$output_indel = $output . ".indel";		
	}
	elsif($self->output_snp && $self->output_indel)
	{
		$output_snp = $self->output_snp;
		$output = $output_snp;
		$output_indel = $self->output_indel;
	}
	else
	{
		die "Please provide an output basename (--output) or output files for SNPs (--output-snp) and indels (--output-indels)\n";
	}


	my $reference = '/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa';
	$reference = $self->reference if($self->reference);
	my $varscan_params = "--min-coverage 8 --min-var-freq 0.08 --p-value 0.10 --somatic-p-value 0.05 --strand-filter 1 --copynumber"; #--min-coverage 8 --verbose 1
	$varscan_params = $self->varscan_params if($self->varscan_params);

	## Check skip if output present ##
	
	if($self->skip_if_output_present)
	{
		if(-e $output_snp)
		{
			my $snp_len = `cat $output_snp | wc -l`;
			chomp($snp_len);
			if($snp_len > 1)
			{
				return 1;
			}
		}
	}

	if(-e $normal_bam && -e $tumor_bam)
	{
		## Get the flagstat ##
		
		my %normal_flagstat = get_flagstat($normal_bam);
		my %tumor_flagstat = get_flagstat($tumor_bam);

		my $normal_readlen = avg_read_len($normal_bam);
		my $tumor_readlen = avg_read_len($tumor_bam);
		
		## Determine the total unique GBP ##
		
		my $normal_unique_bp = ($normal_flagstat{'mapped'} - $normal_flagstat{'duplicates'}) * $normal_readlen;
		my $tumor_unique_bp = ($tumor_flagstat{'mapped'} - $tumor_flagstat{'duplicates'}) * $tumor_readlen;

		my $normal_tumor_ratio = $normal_unique_bp / $tumor_unique_bp;
		$normal_tumor_ratio = sprintf("%.4f", $normal_tumor_ratio);

		print "Normal: $normal_readlen ==> $normal_unique_bp\n";
		print "Tumor: $tumor_readlen ==> $tumor_unique_bp\n";
		print "Ratio: $normal_tumor_ratio\n";
		## Prepare pileup commands ##
		
#		my $normal_pileup = "samtools pileup -f $reference $normal_bam";
#		my $tumor_pileup = "samtools pileup -f $reference $tumor_bam";
		my $normal_pileup = "samtools view -b -u -q $min_map_qual $normal_bam | samtools pileup -f $reference -";
		my $tumor_pileup = "samtools view -b -u -q $min_map_qual $tumor_bam | samtools pileup -f $reference -";

		
		my $cmd = "bash -c \"java -classpath ~dkoboldt/Software/VarScan net.sf.varscan.VarScan somatic <\($normal_pileup\) <\($tumor_pileup\) --output $output --output-snp $output_snp --output-indel $output_indel --data-ratio $normal_tumor_ratio $varscan_params\"";

		## Run VarScan ##
		if($self->heap_space)
		{
#			system("java -Xms" . $self->heap_space . "m -Xmx" . $self->heap_space . "m -classpath ~dkoboldt/Software/VarScan net.sf.varscan.VarScan somatic <($normal_pileup) <($tumor_pileup) $output $varscan_params");						
		}

		print "Running $cmd\n";
		system($cmd);


		## Run the filter command ##
		
		if(-e $output_snp && -e $output_indel)
		{
			$cmd = "java -classpath ~dkoboldt/Software/VarScan net.sf.varscan.VarScan somaticFilter $output_snp --indel-file $output_indel --output-file $output_snp.filter";
			print "Running $cmd\n";
			system($cmd);
			
			if(-e "$output_snp.filter")
			{
				system("mv -f $output_snp $output_snp.unfiltered");
				system("mv -f $output_snp.filter $output_snp");
			}
		}

	}
	else
	{
		die "Error: One of your BAM files doesn't exist!\n";
	}
	
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}





###################################################
# get_flagstat - 
#
###################################################

sub get_flagstat
{
	my $bam_file = shift(@_);
	my $flagstat = "";
	
	if(-e "$bam_file.flagstat")
	{
		$flagstat = `cat $bam_file.flagstat`;	
	}
	else
	{
		$flagstat = `samtools flagstat $bam_file`;
	}


	## IF we got it, parse it ##

	if($flagstat)
	{
		my %cov_stats = ();	
		my @lines = split(/\n/, $flagstat);
		
		foreach my $line (@lines)
		{
			(my $num_reads) = split(/\s+/, $line);
			my $category = $line;
			$category =~ s/$num_reads\s//;
			
			## Remove stuff with parentheses ##
			my $split_char = " \\(";
			($category) = split(/$split_char/, $category);
			
			$cov_stats{$category} = $num_reads if($category);			
		}
		
		return(%cov_stats);
	}
	
	return();
}






#############################################################
# ParseFile - takes input file and parses it
#
#############################################################

sub avg_read_len
{
	my $FileName = shift(@_);

	my $len_sum = my $len_num = 0;
	my $read_seqs = `samtools view $FileName 2>/dev/null | head -10000 | cut -f 10`;

	my @lines = split(/\n/, $read_seqs);
	foreach my $line (@lines)
	{
		my $read_len = length($line);
		$len_sum += $read_len;
		$len_num++;
	}

	my $avg_readlen = $len_sum / $len_num;
	$avg_readlen = sprintf("%.2f", $avg_readlen);
	return($avg_readlen);
}


1;

