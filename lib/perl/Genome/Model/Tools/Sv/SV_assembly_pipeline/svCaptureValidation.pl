#!/usr/bin/env perl -w
# -*- Perl -*-

#
# svCaptureValidation.pl
#
# 
#
#
#  Run on 64-bit machine
#   bsub -q interactive -R 'select[type==LINUX64 && mem>8000] rusage[mem=8000]' -Is $SHELL

use strict;
use Carp;
use Getopt::Long;
use Statistics::Descriptive;
use FindBin qw($Bin);
use lib "$FindBin::Bin";
use ReadRemap;
use BreakDancerLine;

my $Debug = 0;
my $Verbose = 0;  # This is to see the read alignments for SV-specific reads

# Se
my $RemoveDuplicateReadSequence = 0;


# Get reads and unmapped mates +/- $Buffer of breakpoints. 
# Get reference  +/- 2*$Buffer of breakpoints. 
my $Buffer = 500;

my $CrossMatchParameters = "-minmatch 10 -maxmatch 10 -minscore 15";
my $Extend = 2;  # number of bases beyond breakpoint that the read has to span


my ( %TissueToBamFile, $AssemblyFastaFile, $SvFile);
#  -bamFiles tumor=fullPathToBamFile -bamFiles normal=fullPathToBamFile
&GetOptions( "bamFiles=s%" => \%TissueToBamFile,
             "assemblyFile=s" => \$AssemblyFastaFile,           
             "svFile=s"    => \$SvFile
    );
# Make sure all parameters were entered
checkParameters();

# Parse SV file to get hash of regions and hash of fasta header IDs
my ($RegionsRef, $IdRef) = regionsAndFastaIds();

my $ContigSequenceFile = "/tmp/contigSequenceFile".rand();
my $ReferenceSequenceFile = "/tmp/refSequenceFile".rand();

# Get SV contig sequences and put into *fasta file
# This just goes through and pulls out the contigs that are listed in SV file.  It should be a subset of the
# total contigs found in $AssemblyFastaFile.  The point is to only compare reads to the assembly
# contigs of interest.
# At the same time, the fasta header to the value 
$IdRef = ReadRemap::getAssemblySequences($IdRef, $AssemblyFastaFile, $ContigSequenceFile);

# Get regions surrounding each SV breakpoint from Build36 reference and put into *fasta file
ReadRemap::getBuild36ReferenceSequences($RegionsRef, $ReferenceSequenceFile, 2*$Buffer);

# Now go through each SV entry and look for read support from each *.bam file
open(IN, "< $SvFile") || die "Could not open '$SvFile': $!";
my @entireFile = <IN>;
close IN;
foreach my $line (@entireFile) {
    chomp $line;
    if ( $line =~ /^\#/ ) { 
	print "$line\tfastaHeader\tbreakPointAmbiguity"; 
	foreach my $tissue (sort keys %TissueToBamFile) {
	    print "\t$tissue.totalReads\t$tissue.totalUniqueSequenceReads\t$tissue.SvSpecificReads\t$tissue.UniqueAlignmentSvSpecificReads\t$tissue.CrossingBreakpoint\t$tissue.UniqueAlignmentCrossingBreakpoint\t$tissue.UniqueAlignmentCrossingBreakpointNotCloseToReference";
	}
	print "\n";
	next; 
    }
    remapByCrossMatch($line);
}  
unlink $ContigSequenceFile;
unlink $ReferenceSequenceFile;



sub remapByCrossMatch {
    # Only consider reads that hit assembly contig and DO NOT hit reference at all using given filter


    my $line = $_[0];

    my $bdRef = BreakDancerLine->new($line);
    my ($chrA, $bpA, $chrB, $bpB) = $bdRef->chromosomesAndBreakpoints();
    defined ( $bpA && $bpA =~ /^\d+$/ && defined $bpB && $bpB =~ /^\d+$/ ) ||
    confess "Did not get chr and breakpoints from '$line'";
    my $id = $bdRef->Id();

    my ( %uniqueToSv, %svHitCrossingBreakpoints, $contigStart, $contigStop, $fastaHeader, );

    # fasta header has the breakpoint positions.  Remove '>' so it can be compared to the target name
    $fastaHeader = $$IdRef{$id}; $fastaHeader =~ s/\>//;

    if ( $Verbose ) { print "\n\n"; }

    # The breakpoints on the SV contig are encoded in the fasta header
    if ( $fastaHeader =~ /Ins\:(\d+)\-(\-|\d+)/ ) {
	$contigStart = $1; $contigStop = $2;
    } elsif ( $fastaHeader == 0 ) {
	print "No fasta sequence \t $line \n";
	return;
    } else {
	confess "Unexpected format for fasta header.  Did not get breakpoints on SV contig: '$fastaHeader'";
    }
    
    ( defined $contigStart && defined $contigStop ) ||
	confess "Did not get breakpoints on SV contig from '$fastaHeader'";
    if ( $contigStop eq "-" ) { $contigStop = $contigStart; }


    # Print out SV line, fasta header and breakpoint ambiguity
    print "$line\t$fastaHeader\t", $contigStop-$contigStart;
    
    # Remap reads from each *bam file
    foreach my $tissue (sort keys %TissueToBamFile) {

	my $bamFile = $TissueToBamFile{$tissue};
	%uniqueToSv = %svHitCrossingBreakpoints = ();

	# Get all reads surrounding each breakpoint. The regions may overlap with buffer so make sure reads are unique
	my $readRef = ReadRemap::getReads($chrA, $bpA-$Buffer, $bpA+$Buffer, $bamFile);
	my %uniqueEntries = ();
	foreach ( @{$readRef} ) { $uniqueEntries{$_} = 1; }
	$readRef = ReadRemap::getReads($chrB, $bpB-$Buffer, $bpB+$Buffer, $bamFile);
	foreach ( @{$readRef} ) { $uniqueEntries{$_} = 1; }
	my @reads = keys %uniqueEntries;

	# Print out the number of reads before and after removing duplicates
	print "\t", scalar(@reads);
	
	$readRef = ReadRemap::uniqueSamSequenceReads(\@reads);
	print "\t", scalar(@{$readRef});

	# Before doing alignment, remove duplicate sequences if flag is set
	if ( $RemoveDuplicateReadSequence ) {
	    @reads = @{$readRef};
	}

	# Align reads to assembly contigs using cross_match
	my $tempFile = "/tmp/tempReads.fasta".rand();
	my $writeQualityFile = 1;

	ReadRemap::convertSamToFasta(\@reads, $tempFile, $writeQualityFile);
	my $crossMatchResults = ReadRemap::runCrossMatch($tempFile, $ContigSequenceFile, $CrossMatchParameters);
	my $hitsToAssemblyRef = ReadRemap::createHitObjects($crossMatchResults);

	if ( $Debug ) { print "Got ", scalar(keys %{$hitsToAssemblyRef}), " hit objects to assembly contigs \n"; }
	if ( $Debug ) { print "@{$crossMatchResults}\n"; }
	
	# Align reads to normal
	$crossMatchResults = ReadRemap::runCrossMatch($tempFile, $ReferenceSequenceFile, $CrossMatchParameters);
	my $hitsToNormalRef = ReadRemap::createHitObjects($crossMatchResults);

	if ( $Debug ) { print "Got ", scalar(keys %{$hitsToNormalRef}), " hit objects to reference \n"; }
	if ( $Debug ) { print "@{$crossMatchResults}\n"; }
	

	# Remove the files used/created by cross_match
	unlink $tempFile;
	unlink "$tempFile.qual";
	unlink "$tempFile.log";
    	
	# See how many reads uniquely hit assembly contig and how many also cross breakpoint
	foreach my $hitName (keys %{$hitsToAssemblyRef}) {

	    # Skip if this read is not aligned to the assembly contig of interest
	    # The subject should equal the fasta header
	    if ( $$hitsToAssemblyRef{$hitName}->subjectName() ne $fastaHeader ) {
		if ( $Debug ) {	print "Different SV contig: \t", $$hitsToAssemblyRef{$hitName}->alignmentLine(), "\n"; }
		next;
	    }

	    # Skip if read does not pass the filter
	    if ( !ReadRemap::crossMatchHitPassesFilter($$hitsToAssemblyRef{$hitName}) ) {
		if ( $Debug ) {	print "Bad alignment: \t ", $$hitsToAssemblyRef{$hitName}->alignmentLine(), "\n"; }
		next;
	    }

	    # Skip if this read hits reference and the alignment passes filter. 
	    if ( defined $$hitsToNormalRef{$hitName} && ReadRemap::crossMatchHitPassesFilter($$hitsToNormalRef{$hitName}) ) { 
		if ( $Debug ) { 
		    print "Skipping assembly: \t ", $$hitsToAssemblyRef{$hitName}->alignmentLine(), "\n";
		    print "Skipping reference:\t ", $$hitsToNormalRef{$hitName}->alignmentLine(), "\n";
		}
		next; 
	    }

	    # This read uniquely hits assembly contig; it does not hit reference
	    $uniqueToSv{$hitName} = $$hitsToAssemblyRef{$hitName};

	    # Now see if hit crosses breakpoints. 
	    # If the event is an insertion, only require reads to cross one of the breakpoints
	    # All other events, read has to cross both breakpoints
	    # The file format should probably be improved so it gives a range for both breakpoints
	    if ( $fastaHeader =~ /\.INS\./ ) {
		if ( ReadRemap::crossMatchHitCrossesBreakpoints($$hitsToAssemblyRef{$hitName}, $contigStart-$Extend, $contigStart+$Extend) ||
		     ReadRemap::crossMatchHitCrossesBreakpoints($$hitsToAssemblyRef{$hitName}, $contigStop-$Extend, $contigStop+$Extend)
		    ) { $svHitCrossingBreakpoints{$hitName} = $$hitsToAssemblyRef{$hitName}; }
		
	    } else  {
		# Event is not an insertion; reads have to cross both breakpoints
		# For inversions, only one of two breakpoints is reported so the two values represents the range for the given breakpoint
		if ( ReadRemap::crossMatchHitCrossesBreakpoints($$hitsToAssemblyRef{$hitName}, $contigStart-$Extend, $contigStop+$Extend) ) {
		    $svHitCrossingBreakpoints{$hitName} = $$hitsToAssemblyRef{$hitName};
		}
	    }
	} # matches 'foreach my $hitName'.  Finished all hits to assembly contig '$id'


	if ( $Verbose ) { print "\n$tissue"; }

	# Get SV-specific reads that have unique alignments
	my $svSpecificUniqueAlignment = ReadRemap::uniqueCrossMatchAlignments( \%uniqueToSv );

	# Get SV-specific reads that cross the breakpoint and have unique alignments
	my $crossBreakpointUniqueAlignment = ReadRemap::uniqueCrossMatchAlignments( \%svHitCrossingBreakpoints );


	# Get SV-specific reads that cross the breakpoint and have unique alignments and do not have a hit to reference that is of similar
	# quality to the hit to the SV contig


	# print out \t$tissue.SvSpecificReads\t$tissue.UniqueAlignmentSvSpecificReads\t$tissue.CrossingBreakpoint\t$tissue.UniqueAlignmentCrossingBreakpoint\t$tissue.UniqueAlignmentCrossingBreakpointNotCloseToReference
	
	if ( !$Verbose ) {
	    print "\t", scalar(keys %uniqueToSv), 
	    "\t", scalar(keys %{$svSpecificUniqueAlignment}),  
	    "\t", scalar(keys %svHitCrossingBreakpoints), 
	    "\t", scalar(keys %{$crossBreakpointUniqueAlignment}),
	    "\t NotDone";
	}

 

	if ( $Verbose ) {
	    print "\n";
	    # print out the alignments for SV-specific hits along with the hit to reference (if it exists)
	    foreach my $hitName (keys %uniqueToSv) {
		print  "$tissue contig:  ", $$hitsToAssemblyRef{$hitName}->alignmentLine(), "\n";
		if ( defined $$hitsToNormalRef{$hitName} ) { print  "$tissue refrnc:  ",$$hitsToNormalRef{$hitName}->alignmentLine(), "\n"; }
	    }
	}

    } # matches 'foreach (sort keys %TissueToBamFile)'.  Got results for all tissues (generally 'tumor' and 'normal')
    print "\n";

} # end of sub

sub regionsAndFastaIds {
    # Return: ref to hash of regions with keys "$chrA.$bpA.$chrB.$bpB"
    #         ref to hash of fasta header IDs with key = id, value = 0
    # return (\%regions, \%ids); 
    # Get this info from SV file

    my (@entireFile, $line, $chrA, $chrB, $bpA, $bpB, $id, %regions, %ids, );
    open(IN, "$SvFile") || die "Could not open '$SvFile': $!";
    @entireFile = <IN>;
    close IN;
    foreach $line (@entireFile) {
	chomp $line;
	($line !~ /\#/) || next; 
	 my $bdRef = BreakDancerLine->new($line);
	($chrA, $bpA, $chrB, $bpB) = $bdRef->chromosomesAndBreakpoints();
	defined ( $bpA && $bpA =~ /^\d+$/ && defined $bpB && $bpB =~ /^\d+$/ ) ||
	    confess "Did not get chr and breakpoints from '$line'";
	$id = $bdRef->Id();

	$regions{"$chrA.$bpA.$chrB.$bpB"} = 1;
	$ids{$id} = 0;
    }

    return (\%regions, \%ids);
}

sub checkParameters {
    my $error = "";
    if (!-s $AssemblyFastaFile) { $error .= "\n\tAssembly fasta file was not found.  "; }
    if (!-s $SvFile) { $error .= "\n\tSv file was not found.  "; }
    if (!%TissueToBamFile || scalar(keys %TissueToBamFile) == 0) {
	$error .= "\n\tDid not get any *.bam files.  ";
    }
    foreach (keys %TissueToBamFile) {
	if (!-s $TissueToBamFile{$_}) { $error .= "\n\t*.bam file for $_ not found.  "; }
    }
    ($error eq "") ||
	die "USAGE: svCaptureValidation.pl -assemblyFile fullPathToFile -svFile fullPathToFile -bamFiles tumor=fullPathToFile -bamFiles normal=fullPathToFile \n $error";
}






=head
sub remapByCrossMatch {
#sub svContigQuality_test {
    #   (cut-and-paste of 'sub remapByCrossMatch')
    # Get all reads that align better to SV contig, ignoring breakpoints
    # Print out number of reads per position

    
    
    my ($fastaHeader, $assemblyFastaFile, $referenceFasta, $bamFile, $extend) = @_;
    my ($chrA, $bpA, $chrB, $bpB, $contigStart, $contigStop, %uniqueReads, @reads, 
	$readRef, $crossMatchSupported, %positionToReadCount, );

    $crossMatchSupported = 0;

    if ( $fastaHeader =~ /Var\.(\w+)\.(\d+)\.(\w+)\.(\d+)/ ) {
	$chrA = $1; $bpA = $2; $chrB = $3; $bpB = $4;
    } else {
	confess "Can't find chromosomes and breakpoints.  Unexpected format for fasta header '$fastaHeader': $!";
    }

	
    # Get all reads surrounding each breakpoint
    $readRef = ReadRemap::getReads($chrA, $bpA-$Buffer, $bpA+$Buffer, $bamFile);
    foreach ( @{$readRef} ) { $uniqueReads{$_} = 1; }
    $readRef = ReadRemap::getReads($chrB, $bpB-$Buffer, $bpB+$Buffer, $bamFile);
    foreach ( @{$readRef} ) { $uniqueReads{$_} = 1; }

    @reads = keys %uniqueReads;

    # Remap the reads using cross_match and see how many are supported
    my $tempFile = "/tmp/tempReads.fasta".rand();
    my $writeQualityFile = 1;
    ReadRemap::convertSamToFasta(\@reads, $tempFile, $writeQualityFile);
    my $crossMatchResults = ReadRemap::runCrossMatch($tempFile, $assemblyFastaFile, $CrossMatchParameters);
    my $hitObjRef = ReadRemap::createHitObjects($crossMatchResults);

    # Align reads to normal
    $crossMatchResults = ReadRemap::runCrossMatch($tempFile, $referenceFasta, $CrossMatchParameters);
    my $hitsToNormalRef = ReadRemap::createHitObjects($crossMatchResults);
    
    # See how many reads support event according to cross_match
    foreach my $hitName (keys %{$hitObjRef}) {

	# Skip if read does not pass the filter or does not hit the assembly contig under consideration
	if ( !ReadRemap::crossMatchHitPassesFilter($$hitObjRef{$hitName}) ||
	     $$hitObjRef{$hitName}->subjectName() ne $fastaHeader ) { next; }

	# See if this read hits the normal reference with the same or better score than alignment to assembly contig
	if ( defined $$hitsToNormalRef{$hitName} && 
	     $$hitsToNormalRef{$hitName}->score() >= $$hitObjRef{$hitName}->score() ) {
	    next;
	}



	# Just see if the read hit reference and alignment passes filter.  Don't compare scores
	# This is more strict
	#  Compare the hits to normal to hits to assembly contig and if they are very similar, then discard
	#  e.g.  mismatches, etc within 1 or 2 percent -- but not zero.  unaligned at ends within 1 or so -- but not zero
  87  3.03 0.00 0.00  HWI-EAS324_102950683:5:57:9392:1541#0.51M49S.1187        1    99 (1)    10.1.tumor.Var.10.28864148.12.870062.CTX.274.Ins.775_779.Length.1531      668   766 (765)  
  84  4.04 0.00 0.00  HWI-EAS324_102950683:5:57:9392:1541#0.51M49S.1187        1    99 (1)    chromosome:NCBI36:12:869062:871062:1      890   988 (1013)  

  85  3.09 0.00 0.00  HWI-EAS324_102950683:5:82:16822:2601#0.40M60S.99        1    97 (3)    10.1.tumor.Var.10.28864148.12.870062.CTX.274.Ins.775_779.Length.1531      667   763 (768)  
  82  4.12 0.00 0.00  HWI-EAS324_102950683:5:82:16822:2601#0.40M60S.99        1    97 (3)    chromosome:NCBI36:12:869062:871062:1      889   985 (1016)  

  78  3.03 0.00 0.00  HWI-EAS324_102950683:5:114:1833:1936#0.18S82M.1171        1    99 (1)    10.1.tumor.Var.10.28864148.12.870062.CTX.274.Ins.775_779.Length.1531      837   935 (596)  
  75  4.04 0.00 0.00  HWI-EAS324_102950683:5:114:1833:1936#0.18S82M.1171        1    99 (1)    chromosome:NCBI36:10:28863148:28865148:1     1063  1161 (840)  

  88  4.00 0.00 0.00  HWI-EAS324_102950683:5:76:9283:1800#0.79M21S.1187        1   100 (0)    10.1.tumor.Var.10.28864148.12.870062.CTX.274.Ins.775_779.Length.1531      644   743 (788)  
  85  5.00 0.00 0.00  HWI-EAS324_102950683:5:76:9283:1800#0.79M21S.1187        1   100 (0)    chromosome:NCBI36:12:869062:871062:1      866   965 (1036)  

  86  4.00 0.00 0.00  HWI-EAS324_102950683:5:57:13376:1387#0.46M54S.163        1   100 (0)    10.1.tumor.Var.10.28864148.12.870062.CTX.274.Ins.775_779.Length.1531      656   755 (776)  
  83  5.00 0.00 0.00  HWI-EAS324_102950683:5:57:13376:1387#0.46M54S.163        1   100 (0)    chromosome:NCBI36:12:869062:871062:1      878   977 (1024)  

  84  3.12 0.00 0.00  HWI-EAS324_102950683:5:53:2173:19453#0.57M43S.1123        1    96 (4)    10.1.tumor.Var.10.28864148.12.870062.CTX.274.Ins.775_779.Length.1531      667   762 (769)  
  81  4.17 0.00 0.00  HWI-EAS324_102950683:5:53:2173:19453#0.57M43S.1123        1    96 (4)    chromosome:NCBI36:12:869062:871062:1      889   984 (1017)  


	if ( defined $$hitsToNormalRef{$hitName} && ReadRemap::crossMatchHitPassesFilter($$hitsToNormalRef{$hitName}) ) { next; }

	if ( ReadRemap::crossMatchHitsSimilar($$hitsToNormalRef{$hitName}, $$hitObjRef{$hitName}) ) { next; } 

	print $$hitObjRef{$hitName}->alignmentLine(), "\n", $$hitsToNormalRef{$hitName}->alignmentLine(), "\n\n";


	# This will not find regions with discontinuity e.g. reads stop at X and others start at X+1, but nothing spans
	my $subjectStart = $$hitObjRef{$hitName}->subjectStart();
	my $subjectEnd = $$hitObjRef{$hitName}->subjectEnd();
	if ( $subjectStart > $subjectEnd ) { ($subjectStart, $subjectEnd) = ($subjectEnd, $subjectStart); }
	foreach ($subjectStart+1..$subjectEnd-1) { $positionToReadCount{$_}++; }

    }


    #my $crossMatchFile = "/tmp/crossMatchResults".rand();
    #open(OUT, "> $crossMatchFile"); print OUT "@{$crossMatchResults}"; close OUT;
    
    unlink $tempFile;
    unlink "$tempFile.qual";
    unlink "$tempFile.log";

    my $totalReadCount = scalar(@reads);

    print "\$totalReadCount = $totalReadCount \n";
    my @positions = sort {$a<=>$b} keys %positionToReadCount;
    print "Holes: \n";
    foreach ($positions[0]..$positions[$#positions]) {
	if ( !defined $positionToReadCount{$_}  ) { print "$_ "; }
    }

    print "\n"; 
    foreach (sort {$a<=>$b} keys %positionToReadCount) { print "$_:$positionToReadCount{$_} "; }

}
=cut
