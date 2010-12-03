package Genome::Model::Tools::Varscan::PullOneTwoBpIndels;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# GermlinePipelineFinisher - Generate MAF File, Get dbsnp output, and strandfilter -- for GERMLINE events
#					
#	AUTHOR:		Will Schierding (wschierd@genome.wustl.edu)
#
#	CREATED:	09/29/2010 by W.S.
#	MODIFIED:	09/29/2010 by W.S.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Varscan::PullOneTwoBpIndels {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		project_name	=> { is => 'Text', doc => "Name of the project i.e. ASMS" , is_optional => 1},
		file_list	=> { is => 'Text', doc => "File of indel files to include, 1 name per line, tab delim, no headers. Should be chr start stop ref var blahhhhhhhhhhhh." , is_optional => 0},
		small_indel_outfile	=> { is => 'Text', doc => "File of small indels to be realigned" , is_optional => 0},
		tumor_bam	=> { is => 'Text', doc => "Tumor Bam File (Validation Bam)" , is_optional => 0},
		normal_bam	=> { is => 'Text', doc => "Normal Bam File (Validation Bam)" , is_optional => 0},
		reference_fasta	=> { is => 'Text', doc => "Reference Fasta" , is_optional => 0, default => "/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa"},

	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Generate list of 1-2 bp indels, run GATK recalibration, and then sort and index bams"                 
}

sub help_synopsis {
    return <<EOS
Generate list of 1-2 bp indels, run GATK recalibration, and then sort and index bams
EXAMPLE:	gmt varscan pull-one-two-bp-indels
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
	my $project_name = $self->project_name;
	my $small_indel_list = $self->small_indel_outfile;
	my $file_list_file = $self->file_list;
	my $normal_bam = $self->normal_bam;
	my $tumor_bam = $self->tumor_bam;
	my $reference = $self->reference_fasta;

	unless ($small_indel_list =~ m/\.bed/i) {
		die "Indel File Must end in .bed";
	}

	my $realigned_normal_bam_file = $normal_bam;
	$realigned_normal_bam_file =~ s/\.bam//;
	$realigned_normal_bam_file = "$realigned_normal_bam_file.realigned.bam";
	my $sorted_normal_bam_file = $realigned_normal_bam_file;
	$sorted_normal_bam_file =~ s/\.bam//;
	$sorted_normal_bam_file = "$sorted_normal_bam_file.sorted";

	my $realigned_tumor_bam_file = $tumor_bam;
	$realigned_tumor_bam_file =~ s/\.bam//;
	$realigned_tumor_bam_file = "$realigned_tumor_bam_file.realigned.bam";
	my $sorted_tumor_bam_file = $realigned_tumor_bam_file;
	$sorted_tumor_bam_file =~ s/\.bam//;
	$sorted_tumor_bam_file = "$sorted_tumor_bam_file.sorted";

	## Open the outfiles ##
	my $indel_outfile = $small_indel_list;
	open(INDELS_OUT, ">$indel_outfile") or die "Can't open output file: $!\n";

#	my @file_list;
	my $file_input = new FileHandle ($file_list_file);
	while (my $file = <$file_input>) {
		chomp($file);
#		push(@file_list,$file);
		my $indel_input = new FileHandle ($file);
		while (my $line = <$indel_input>) {
			chomp($line);
			my ($chr, $start, $stop, $ref, $var, @everything_else) = split(/\t/, $line);
			my $size = ($stop - $start);
			if ($size <= 1) {
				my $bedstart = ($start - 1);
				print INDELS_OUT "$chr\t$bedstart\t$stop\t$ref\t$var\n";
			}
		}
		close($indel_input);
	}
	close($file_input);

	my $bsub = 'bsub -q apipe -R "select[model!=Opteron250 && type==LINUX64 && mem>8000 && tmp>1000] rusage[mem=8000, tmp=1000]" -M 8000000 ';
	my $jobid1 = `$bsub -J $realigned_normal_bam_file \'java -Xmx4g -Djava.io.tmpdir=/tmp -jar /gscuser/dkoboldt/Software/GATK/GenomeAnalysisTK-1.0.4418/GenomeAnalysisTK.jar -T IndelRealigner -targetIntervals $small_indel_list -o $realigned_normal_bam_file -I $normal_bam -R $reference  -compress 0 --targetIntervalsAreNotSorted\'`;
	   $jobid1=~/<(\d+)>/;
	   $jobid1= $1;
	   print "$jobid1\n";
	my $jobid2 = `$bsub -J $realigned_tumor_bam_file \'java -Xmx4g -Djava.io.tmpdir=/tmp -jar /gscuser/dkoboldt/Software/GATK/GenomeAnalysisTK-1.0.4418/GenomeAnalysisTK.jar -T IndelRealigner -targetIntervals $small_indel_list -o $realigned_tumor_bam_file -I $tumor_bam -R $reference  -compress 0 --targetIntervalsAreNotSorted\'`;
	   $jobid2=~/<(\d+)>/;
	   $jobid2= $1;
	   print "$jobid2\n";

	my $jobid3 = `$bsub -J bamsort_normal -w \'ended($jobid1)\' \'samtools sort $realigned_normal_bam_file $sorted_normal_bam_file\'`;
	   $jobid3=~/<(\d+)>/;
	   $jobid3= $1;
	   print "$jobid3\n";
	my $jobid4 = `$bsub -J bamsort_tumor -w \'ended($jobid2)\' \'samtools sort $realigned_tumor_bam_file $sorted_tumor_bam_file\'`;
	   $jobid4=~/<(\d+)>/;
	   $jobid4= $1;
	   print "$jobid4\n";

	my $jobid5 = `$bsub -J bamindex_normal -w \'ended($jobid3)\' \'samtools index $sorted_normal_bam_file.bam\'`;
	my $jobid6 = `$bsub -J bamindex_tumor -w \'ended($jobid4)\' \'samtools index $sorted_tumor_bam_file.bam\'`;
}

















