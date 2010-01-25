
package Genome::Model::Tools::Blat::MatchToAmplicons;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# MatchToAmplicons.pm -	Match reads to amplicons using read alignments and amplicon refseq FASTA headers
#					
#	AUTHOR:		Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#	CREATED:	10/20/2008 by D.K.
#	MODIFIED:	12/02/2008 by D.K.
#
#	NOTES:		After PyroScan code has been improved and deployed, use LSF to run pyroscan
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
		lsf_queue	=> { is => 'Text', doc => "LSF queue if other than long [long]", is_optional => 1 },
		output_dir	=> { is => 'Text', doc => "Directory where amplicon subdirs/files will be created [amplicon_dir]", is_optional => 1 },
		sff_file	=> { is => 'Text', doc => "SFF file containing all reads", is_optional => 1 },	
		skip_refseq	=> { is => 'Text', doc => "If set to 1, do not build amplicon refseqs [0]", is_optional => 1 },
		skip_fof	=> { is => 'Text', doc => "If set to 1, do not build per-amplicon read FOFs [0]", is_optional => 1 },
		skip_counts	=> { is => 'Text', doc => "If set to 1, do not report amplicon readcounts [0]", is_optional => 1 },		
		run_crossmatch	=> { is => 'Text', doc => "If set to 1, launch CM alignments between reads and amplicon [0]", is_optional => 1 },	
		run_pyroscan	=> { is => 'Text', doc => "If set to 1, run PyroScan on the CM output file [0]", is_optional => 1 },
		convert_pyroscan	=> { is => 'Text', doc => "If set to 1, convert PyroScan output to genotype sub file [0]", is_optional => 1 },		
		pyroscan_params	=> { is => 'Text', doc => "Optional parameters to use for pyroscan", is_optional => 1 },	
		overlap_bases	=> { is => 'Text', doc => "Minium overlapping bp to assign read to an amplicon [1]", is_optional => 1 },	
		blocks_file	=> { is => 'Text', doc => "Best-blocks file if RefCov layers are desired", is_optional => 1 },		
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Match aligned reads to amplicon reference sequences"                 
}

sub help_synopsis {
    return <<EOS
This command matches reads to amplicon refseqs using read alignments and amplicon coordinates
EXAMPLE 1:	gmt blat match-to-amplicons --alignments-file myBlatOutput.psl.best-aligns.txt --headers-file amplicons.txt --sample-name mySample
	=> Generates amplicon subdirectories under amplicon_dir, builds amplicon refseqs and reads FOF files

EXAMPLE 2:	gmt blat match-to-amplicons --alignments-file myBlatOutput.psl.best-aligns.txt --headers-file amplicons.txt --sample-name mySample --sff-file mySample.sff
	=> Generates amplicon subdirectories under amplicon_dir, builds amplicon refseqs and reads FOF/SFF/Fasta/Qual

EXAMPLE 3:	gmt blat match-to-amplicons --alignments-file myBlatOutput.psl.best-aligns.txt --headers-file amplicons.txt --sample-name mySample --run-crossmatch 1
	=> Same as example 1, but also launches cross_match alignments on the blades

EXAMPLE 4:	gmt blat match-to-amplicons --alignments-file myBlatOutput.psl.best-aligns.txt --headers-file amplicons.txt --sample-name mySample --run-pyroscan 1
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
	

	## Set defaults for and then get optional parameters ##
	
	my $lsf_queue = "long";
	my $output_dir = "amplicon_dir";	
	my $refseq_dir = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/";	
	my $min_overlap_bases = 1;
	my $sff_file = "";
	
	$sff_file = $self->sff_file if($self->sff_file);	
	$lsf_queue = $self->lsf_queue if($self->lsf_queue);
	$output_dir = $self->output_dir if($self->output_dir);
	$min_overlap_bases = $self->overlap_bases if($self->overlap_bases);	
	
	## Grab options on which steps to run ##
	
	my $skip_refseq = $self->skip_refseq if($self->skip_refseq);
	my $skip_fof = $self->skip_fof if($self->skip_fof);	
	my $skip_counts = $self->skip_counts if($self->skip_counts);	
	my $run_crossmatch = $self->run_crossmatch if($self->run_crossmatch);
	my $run_pyroscan = $self->run_pyroscan if($self->run_pyroscan);
	my $convert_pyroscan = $self->convert_pyroscan if($self->convert_pyroscan);	
	my $pyroscan_params = $self->pyroscan_params if($self->pyroscan_params);
	my $blocks_file = $self->blocks_file if($self->blocks_file);

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
	
	
	
	
	## If a best blocks file was specified, parse it ##
	my %ReadBlocks = ();
	if($blocks_file && -e $blocks_file)
	{
		my $input = new FileHandle ($blocks_file);
		my $lineCounter = 0;
		
		while (<$input>)
		{
			chomp;
			my $line = $_;
			$lineCounter++;		
		
			if($lineCounter > 1)
			{
				my @lineContents = split(/\t/, $line);
				my $read_name = $lineContents[4];
				$ReadBlocks{$read_name} .= "$line\n";
			}
		}
		
		close($input);	
		print "$lineCounter alignment blocks parsed from $blocks_file\n";
	}
	
	
	my %AmpliconReads = my %NumAmpliconReads = ();
	my %AmpliconLayers = ();

	## Parse the read alignments file ##
	print "Parsing alignments file...\n";

	print "Requiring $min_overlap_bases overlapping bases to assign read to an amplicon\n";

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
						## Calculate the amount of overlap ##
						my $overlap_start = $amplicon_start;
						$overlap_start = $chr_start if($chr_start > $amplicon_start);
						my $overlap_stop = $amplicon_stop;
						$overlap_stop = $chr_stop if($chr_stop < $amplicon_stop);
						my $overlap_bases = $overlap_stop - $overlap_start + 1;
						
						if($overlap_bases >= $min_overlap_bases)
						{
							$AmpliconReads{$amplicon_name} .= "$read_name\n";
							$NumAmpliconReads{$amplicon_name}++;
							if($ReadBlocks{$read_name})
							{
								$AmpliconLayers{$amplicon_name} .= $ReadBlocks{$read_name};
							}
						}
					}
				}
			}
		}
	}
	
	close($input);
	
	
	
	## Get the Reference Fasta Database ##
	
	my $refseqdb = Bio::DB::Fasta->new($refseq_dir); 
	
	
	## Open master blocks output file ##
	
	if($blocks_file && -e $blocks_file)
	{
		open(READLAYERS, ">$output_dir/$sample_name.amplicons.layers") or die "Can't open outfile: $!\n";		
	}
	
	## Open the output files ##
	if(!$skip_counts)
	{
		open(READCOUNTS, ">$output_dir/$sample_name.amplicons.readcounts") or die "Can't open outfile: $!\n";
		print READCOUNTS "chrom\tchr_start\tchr_stop\tamplicon_name\tnum_reads\n";
	}
	
	## Print the amplicon coverage ##
	my $ampCounter = 0;
	
	foreach my $amplicon (keys %Amplicons)
	{
		$ampCounter++;
		(my $chrom, my $chr_start, my $chr_stop) = split(/\t/, $Amplicons{$amplicon});
		my $num_reads = $NumAmpliconReads{$amplicon};
		$num_reads = 0 if(!$num_reads);
		print READCOUNTS "$chrom\t$chr_start\t$chr_stop\t$amplicon\t$num_reads\n" if(!$skip_counts);
		print "$ampCounter\t$amplicon\t$num_reads\n";		
	
		## Create the amplicon subdirectory ##
		
		my $amplicon_subdir = $output_dir . "/" . $amplicon;
		system("mkdir $amplicon_subdir") if(!(-d $amplicon_subdir));
		
		## Build the amplicon refseq ##
		
		if(!$skip_refseq)
		{
			open(AMP_REFSEQ, ">$amplicon_subdir/amplicon.refseq.fasta") or die "Can't open amplicon refseq file: $!\n";
			my $amplicon_sequence = $refseqdb->seq($chrom, $chr_start, $chr_stop);
			print AMP_REFSEQ ">$amplicon NCBI Build 36, Chr:$chrom, Coords $chr_start-$chr_stop, Ori (+)\n";
			print AMP_REFSEQ "$amplicon_sequence\n";		
			close(AMP_REFSEQ);
		}
		
		## Build the reads FOF file ##
		
		if(!$skip_fof && $AmpliconReads{$amplicon})
		{
			open(AMP_FOF, ">$amplicon_subdir/traces.$sample_name.fof") or die "Can't create FOF file: $!\n";
			print AMP_FOF $AmpliconReads{$amplicon};
			close(AMP_FOF);
		}
	
		## If best blocks file provided, generate refcov layers ##
	
		if($blocks_file && -e $blocks_file && $AmpliconLayers{$amplicon})
		{
			## Open the layers file ##
		
			open(AMP_LAYERS, ">$amplicon_subdir/traces.$sample_name.layers") or die "Can't create layers file: $!\n";
		
			## Grep out the relevant blocks ##
			
#			my $BestBlocks = `grep -f $amplicon_subdir/traces.$sample_name.fof $blocks_file`;
#			chomp($BestBlocks);
			
			my $BestBlocks = $AmpliconLayers{$amplicon};
			
			my @bestBlockLines = split(/\n/, $BestBlocks);
			foreach my $blockLine (@bestBlockLines)
			{
				my @blockLineContents = split(/\t/, $blockLine);
				my $read_chrom = $blockLineContents[0];
				my $read_chr_start; my $read_chr_stop;
				
				if($blockLineContents[1] > $blockLineContents[2])
				{
					$read_chr_start = $blockLineContents[2];
					$read_chr_stop = $blockLineContents[1];
				}
				else
				{
					$read_chr_start = $blockLineContents[1];
					$read_chr_stop = $blockLineContents[2];				
				}
				
				my $read_name = $blockLineContents[4];
				my $block_no = $blockLineContents[7];
				
				## Adjust to amplicon positions ##
				
				my $read_amp_start = $read_chr_start - $chr_start + 1;
				my $read_amp_stop = $read_chr_stop - $chr_start + 1;
				$read_amp_start = 1 if($read_amp_start < 1);				
				
				## Print the layer ##
				if($read_amp_stop > 0)
				{				
					my $layer = "$read_name.$block_no\t$read_amp_start\t$read_amp_stop\t$amplicon";
					print AMP_LAYERS "$layer\n";
					print READLAYERS "$layer\n";
				}
			}
			
			close(AMP_LAYERS);
		}
	
		## If master SFF file provided, build the sub-SFF file ##
		
		if($sff_file && $num_reads > 0)
		{
			system("sfffile -i $amplicon_subdir/traces.$sample_name.fof -o $amplicon_subdir/traces.$sample_name.sff $sff_file");
			system("sffinfo -s $amplicon_subdir/traces.$sample_name.sff >$amplicon_subdir/traces.$sample_name.fasta");
			system("sffinfo -q $amplicon_subdir/traces.$sample_name.sff >$amplicon_subdir/traces.$sample_name.fasta.qual");		
		}
		
		## If flag specified, run cross_match ##
		
		if($run_crossmatch)
		{
			if(-e "$amplicon_subdir/traces.$sample_name.fasta" && -e "$amplicon_subdir/amplicon.refseq.fasta")
			{
				system("bsub -q $lsf_queue -oo $amplicon_subdir/$sample_name.$amplicon.crossmatch.out cross_match.test $amplicon_subdir/traces.$sample_name.fasta $amplicon_subdir/amplicon.refseq.fasta -minmatch 12 -minscore 25 -penalty -4 -discrep_lists -tags -gap_init -3 -gap_ext -1");		
			}
		}
	
		if($run_pyroscan)
		{
			if(-e "$amplicon_subdir/traces.$sample_name.fasta.qual" && -e "$amplicon_subdir/amplicon.refseq.fasta" && -e "$amplicon_subdir/$sample_name.$amplicon.crossmatch.out")
			{
				if($pyroscan_params)
				{
#					system("bsub -q $lsf_queue -oo $amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan.out \"gmt pyroscan run --cmt $amplicon_subdir/$sample_name.$amplicon.crossmatch.out --qt $amplicon_subdir/traces.$sample_name.fasta.qual --refseq $amplicon_subdir/amplicon.refseq.fasta $pyroscan_params >$amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan\"");
					system("gmt pyroscan run --cmt $amplicon_subdir/$sample_name.$amplicon.crossmatch.out --qt $amplicon_subdir/traces.$sample_name.fasta.qual --refseq $amplicon_subdir/amplicon.refseq.fasta $pyroscan_params >$amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan");				
				}
				else
				{
#					system("bsub -q $lsf_queue -oo $amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan.out \"gmt pyroscan run --cmt $amplicon_subdir/$sample_name.$amplicon.crossmatch.out --qt $amplicon_subdir/traces.$sample_name.fasta.qual --refseq $amplicon_subdir/amplicon.refseq.fasta >$amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan\"");
					system("gmt pyroscan run --cmt $amplicon_subdir/$sample_name.$amplicon.crossmatch.out --qt $amplicon_subdir/traces.$sample_name.fasta.qual --refseq $amplicon_subdir/amplicon.refseq.fasta >$amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan 2>/dev/null");				
				}
				
				#system("gmt pyroscan convert-output --headers-file $amplicon_subdir/amplicon.refseq.fasta --input-file $amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan --output-file $amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan.genotype_submission.tsv --sample-name $sample_name");
			}
		}
	
		if($convert_pyroscan)
		{
			system("gmt pyroscan convert-output --headers-file $amplicon_subdir/amplicon.refseq.fasta --input-file $amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan --output-file $amplicon_subdir/$sample_name.$amplicon.crossmatch.out.pyroscan.genotype_submission.tsv --sample-name $sample_name");
		}
	}
	
	close(READCOUNTS) if(!$skip_counts);
	
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

