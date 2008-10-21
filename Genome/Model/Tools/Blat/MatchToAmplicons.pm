
package Genome::Model::Tools::Blat::MatchToAmplicons;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# MatchToAmplicons.pm -	Match reads to amplicons using read alignments and amplicon refseq FASTA headers
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	10/20/2008 by D.K.
#	MODIFIED:	10/21/2008 by D.K.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;
use Bio::DB::Fasta;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Blat::MatchToAmplicons {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		alignments_file	=> { is => 'Text', doc => "Scored read alignments to genome sequence" },
		headers_file	=> { is => 'Text', doc => "FASTA headers for amplicon sequences" },
		sample_name	=> { is => 'Text', doc => "Descriptive string for naming output files (e.g. tsp_val_round7)" },		
		output_dir	=> { is => 'Text', doc => "Directory where amplicon subdirs/files will be created [amplicon_dir]", is_optional => 1 },
		sff_file	=> { is => 'Text', doc => "SFF file containing all reads", is_optional => 1 },	
		run_crossmatch	=> { is => 'Text', doc => "If set to 1, launch CM alignments between reads and amplicon", is_optional => 1 },	
		run_pyroscan	=> { is => 'Text', doc => "If set to 1, run PyroScan on the CM output file", is_optional => 1 },		
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Match aligned reads to amplicon reference sequences"                 
}

sub help_synopsis {
    return <<EOS
This command matches reads to amplicon refseqs using read alignments and amplicon coordinates
EXAMPLE 1:	gt blat match-to-amplicons --alignments-file myBlatOutput.psl.best-aligns.txt --headers-file amplicons.txt --sample-name mySample
	=> Generates amplicon subdirectories under amplicon_dir, builds amplicon refseqs and reads FOF files

EXAMPLE 2:	gt blat match-to-amplicons --alignments-file myBlatOutput.psl.best-aligns.txt --headers-file amplicons.txt --sample-name mySample --sff-file mySample.sff
	=> Generates amplicon subdirectories under amplicon_dir, builds amplicon refseqs and reads FOF/SFF/Fasta/Qual

EXAMPLE 3:	gt blat match-to-amplicons --alignments-file myBlatOutput.psl.best-aligns.txt --headers-file amplicons.txt --sample-name mySample --run-crossmatch 1
	=> Same as example 1, but also launches cross_match alignments on the blades

EXAMPLE 4:	gt blat match-to-amplicons --alignments-file myBlatOutput.psl.best-aligns.txt --headers-file amplicons.txt --sample-name mySample --run-pyroscan 1
	=> Same as example 1, but also runs Pyroscan on the cross_match output
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
	my $alignments_file = $self->alignments_file;
	my $headers_file = $self->headers_file;
	my $sample_name = $self->sample_name;

	## Set defaults for optional parameters ##
	
	my $output_dir = "amplicon_dir";
	$output_dir = $self->output_dir if($self->output_dir);
	my $refseq_dir = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/";
	my $sff_file = "";
	$sff_file = $self->sff_file if($self->sff_file);
	my $run_crossmatch = $self->run_crossmatch if($self->run_crossmatch);
	my $run_pyroscan = $self->run_pyroscan if($self->run_pyroscan);

	## Verify that alignments file exists ##
	
	if(!(-e $alignments_file))
	{
		print "Alignments file does not exist. Exiting...\n";
		return(0);
	}	

	## Verify that headers file exists ##
	
	if(!(-e $headers_file))
	{
		print "Headers file does not exist. Exiting...\n";
		return(0);
	}	

	## If output dir doesn't exist, create it ##
	system("mkdir $output_dir") if(!(-d $output_dir));

	## Verify that output dir was created ##
	
	if(!(-d $output_dir))
	{
		print "Unable to create output directory $output_dir. Exiting...\n";
		return(0);
	}	

	## Verify SFF file ##

	if($sff_file && !(-e $sff_file))
	{
		print "SFF file does not exist. Exiting...\n";
		return(0);	
	}

	## Parse the amplicon coordinates ##
	
	my %Amplicons = ParseHeadersFile($headers_file);


	## Build amplicons by chrom ##

	my %AmpliconsByChrom = ();
	
	foreach my $amplicon (keys %Amplicons)
	{
		(my $chrom, my $chr_start, my $chr_stop) = split(/\t/, $Amplicons{$amplicon});
		$chrom =~ s/[^0-9XYM]//g;
		$AmpliconsByChrom{$chrom} .= "$chr_start\t$chr_stop\t$amplicon\n";
	}
	
	my %AmpliconReads = my %NumAmpliconReads = ();

	## Parse the read alignments file ##
	print "Parsing alignments file...\n";

	my $input = new FileHandle ($alignments_file);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	
		if($lineCounter > 1)
		{
			my @lineContents = split(/\t/, $line);
			my $read_name = $lineContents[1];
			my $chrom = $lineContents[4];
			my $chr_start = $lineContents[5];
			my $chr_stop = $lineContents[6];
			
			$chrom =~ s/[^0-9XYM]//g;
			
			if($AmpliconsByChrom{$chrom})
			{
				my @amplicons = split(/\n/, $AmpliconsByChrom{$chrom});
				my $num_genes = @amplicons;
				
				for(my $gCounter = 0; $gCounter < $num_genes; $gCounter++)
				{
					(my $amplicon_start, my $amplicon_stop, my $amplicon_name) = split(/\t/, $amplicons[$gCounter]);
					if($chr_stop >= $amplicon_start && $chr_start <= $amplicon_stop)
					{
						$AmpliconReads{$amplicon_name} .= "$read_name\n";
						$NumAmpliconReads{$amplicon_name}++;
					}
				}
			}
		}
	}
	
	close($input);
	
	
	## Get the Reference Fasta Database ##
	
	my $refseqdb = Bio::DB::Fasta->new($refseq_dir); 
	
	
	## Open the output files ##
	
	open(READCOUNTS, ">$output_dir/$sample_name.amplicons.readcounts") or die "Can't open outfile: $!\n";
	print READCOUNTS "chrom\tchr_start\tchr_stop\tamplicon_name\tnum_reads\n";
	
	## Print the amplicon coverage ##
	my $ampCounter = 0;
	
	foreach my $amplicon (keys %Amplicons)
	{
		$ampCounter++;
		(my $chrom, my $chr_start, my $chr_stop) = split(/\t/, $Amplicons{$amplicon});
		my $num_reads = $NumAmpliconReads{$amplicon};
		$num_reads = 0 if(!$num_reads);
		print READCOUNTS "$chrom\t$chr_start\t$chr_stop\t$amplicon\t$num_reads\n";
		print "$ampCounter\t$amplicon\t$num_reads\n";		
	
		## Create the amplicon subdirectory ##
		
		my $amplicon_subdir = $output_dir . "/" . $amplicon;
		system("mkdir $amplicon_subdir") if(!(-d $amplicon_subdir));
		
		## Build the amplicon refseq ##
		
		open(AMP_REFSEQ, ">$amplicon_subdir/amplicon.refseq.fasta") or die "Can't open amplicon refseq file: $!\n";
		my $amplicon_sequence = $refseqdb->seq($chrom, $chr_start, $chr_stop);
		print AMP_REFSEQ ">$amplicon NCBI Build 36, Chr:$chrom, Coords $chr_start-$chr_stop, Ori (+)\n";
		print AMP_REFSEQ "$amplicon_sequence\n";		
		close(AMP_REFSEQ);
		
		## Build the reads FOF file ##
		
		open(AMP_FOF, ">$amplicon_subdir/traces.$sample_name.fof") or die "Can't create FOF file: $!\n";
		print AMP_FOF $AmpliconReads{$amplicon};
		close(AMP_FOF);
	
		## If master SFF file provided, build the sub-SFF file ##
		
		if($sff_file && $num_reads > 0)
		{
			system("sfffile -i $amplicon_subdir/traces.$sample_name.fof -o $amplicon_subdir/traces.$sample_name.sff $sff_file");
			system("sffinfo -s $amplicon_subdir/traces.$sample_name.sff >$amplicon_subdir/traces.$sample_name.fasta");
			system("sffinfo -q $amplicon_subdir/traces.$sample_name.sff >$amplicon_subdir/traces.$sample_name.fasta.qual");		
		}
		
		if($run_crossmatch)
		{
			if(-e "$amplicon_subdir/traces.$sample_name.fasta" && -e "$amplicon_subdir/amplicon.refseq.fasta")
			{
				system("bsub -q long -oo $amplicon_subdir/$sample_name.$amplicon.crossmatch.out cross_match.test $amplicon_subdir/traces.$sample_name.fasta $amplicon_subdir/amplicon.refseq.fasta -minmatch 12 -minscore 25 -penalty -4 -discrep_lists -tags -gap_init -3 -gap_ext -1");		
			}
		}
	
		if($run_pyroscan)
		{
			if(-e "$amplicon_subdir/traces.$sample_name.fasta.qual" && -e "$amplicon_subdir/amplicon.refseq.fasta" && -e "$amplicon_subdir/$sample_name.$amplicon.crossmatch.out")
			{
				system("gt pyroscan run --cmt $amplicon_subdir/$sample_name.$amplicon.crossmatch.out --qt $amplicon_subdir/traces.$sample_name.fasta.qual --refseq $amplicon_subdir/amplicon.refseq.fasta >$amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan");
			}
		}
	}
	
	close(READCOUNTS);
	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}




#############################################################
# ParseHeadersFile - parse headers file 
#
#############################################################

sub ParseHeadersFile
{
	my $FileName = shift(@_);

	my %AmpliconCoords = ();
	my $numAmplicons = 0;

	my $input = new FileHandle ($FileName);
	my $lineCounter = 0;
	
	while (<$input>)
	{
		chomp;
		my $line = $_;
		$lineCounter++;		
	
		if($line && substr($line, 0, 1) eq ">")
		{
			my @lineContents = split(/\s+/, $line);
			my $numContents = @lineContents;
			
			my $amplicon_name = my $amplicon_chrom = my $amplicon_chr_start = my $amplicon_chr_stop = "";
			
			for(my $eCounter = 0; $eCounter < $numContents; $eCounter++)
			{
				if($eCounter == 0)
				{
					$amplicon_name = substr($lineContents[$eCounter], 1, 999);
				}
				if($lineContents[$eCounter] =~ "Chr")
				{
					my @temp = split(/\:/, $lineContents[$eCounter]);
					$amplicon_chrom = $temp[1];
					$amplicon_chrom =~ s/\,//;
				}
				if($lineContents[$eCounter] =~ "Coords")
				{
					($amplicon_chr_start, $amplicon_chr_stop) = split(/\-/, $lineContents[$eCounter + 1]);
					$amplicon_chr_stop =~ s/\,//;
				}
	
			}
	
			if($amplicon_name && $amplicon_chrom && $amplicon_chr_stop && $amplicon_chr_start)
			{
#				$GenesByChrom{$amplicon_chrom} .= "$amplicon_chr_start\t$amplicon_chr_stop\t$amplicon_name\n";
				$AmpliconCoords{$amplicon_name} = "$amplicon_chrom\t$amplicon_chr_start\t$amplicon_chr_stop";
				$numAmplicons++;
			}
		}

	}	
	
	print "$numAmplicons amplicon coordinate sets parsed from $FileName\n";
	
	return(%AmpliconCoords);
}



1;

