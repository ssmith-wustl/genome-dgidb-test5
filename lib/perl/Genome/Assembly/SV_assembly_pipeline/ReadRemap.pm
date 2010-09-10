package ReadRemap;

#
#   Run on 64-bit machine
#
#
#
#
#



use strict;
use Carp;
use FindBin qw($Bin);
use lib "$FindBin::Bin";
#use lib "/gscuser/jwallis/svn/perl_modules/test_project/jwallis";
use Hits;

# This is used to parse the cross_match hits
my $number = "\\d+\\.?\\d*";
my $deleted = "\\(\\s*\\d+\\s*\\)";
my $AlignmentLine = "($number)\\s+($number)\\s+($number)\\s+($number)\\s+(\\S+)\\s+(\\d+)\\s+(\\d+)\\s+($deleted)\\s+(C\\s+)?(\\S+)\\s+($deleted)?\\s*(\\d+)\\s+(\\d+)\\s*($deleted)?";



sub getReads {
    # Input: '$chr' (fasta header used to create *.bam file)
    #         $start, $stop (reads cross ANY bases between $start, $stop inclusive)
    #         $bamFile
    # Return: ref to array of reads that map to anywhere defined by $chr, $start, $stop OR mates of reads that do
    #
    # No minimum quality value is used so mates of mapped reads can be captured.

    my ($chr, $start, $stop, $bamFile) = @_;
    (-e $bamFile) || confess "Could not find '$bamFile': $!";

    open(SAM, "samtools view $bamFile $chr:$start-$stop |") || confess "Could not open pipe to samtools: $!";
    my @breakPointReads = <SAM>;
    close SAM;
    return \@breakPointReads;
}

sub getAssemblySequences {
    # Input: ref to hash of unique ID(s), fasta sequence file, output file
    # Write given sequences to output file
    # Update the values for unique ID hash to get the fasta header

    my ($idRef, $fastaFile, $outputFile ) = @_;
    my ( $reading, @entireFile, $line, $sequence, $sequencesFound, );
    $reading = 0;
    open(IN, "< $fastaFile") || confess "Could not open '$fastaFile': $!";
    @entireFile = <IN>;
    open(OUT, "> $outputFile") || confess "Could not open '$outputFile' for output: $!";
    foreach $line (@entireFile) {
	chomp $line;
	if ( $line =~ />(\w+\.\d+)\,/ ) {
	    if ( defined $$idRef{$1} ) { $reading = 1; $$idRef{$1} = $line; } else { $reading = 0; }
	}
	if ( $reading ) { print OUT "$line\n"; }
    }
    return $idRef;
}

sub getBuild36ReferenceSequences {
    # Input: ref to hash with key = "$chrA.$bpA.$chrB.$bpB", output file, $buffer
    # Use 'expiece' to write region +/- $buffer of each position
    # Chromosome-specific reference sequences are at:
    # /gscmnt/sata180/info/medseq/biodb/shared/Hs_build36/Homo_sapiens.NCBI36.45.dna.chromosome.$chr.fa
    
    my ($positionRef, $outputFile, $buffer) = @_;
    my ( $position, $remove, $chrA, $bpA, $chrB, $bpB, $start, $stop, @output, $seq, );
    if (!defined $buffer) { $buffer = 500; }
    
    open(OUT, "> $outputFile") || confess "Could not open '$outputFile' for output: $!";

    # This is what the fasta header looks like when using 'expiece'.
    # Want to remove the full path to the chromosome
    $remove = "\/gscmnt\/sata180\/info\/medseq\/biodb\/shared\/Hs_build36\/Homo_sapiens.NCBI36.45.dna.chromosome.";

    foreach $position ( sort keys %{$positionRef} ) {
	if ( $position =~ /(\w+)\.(\d+)\.(\w+)\.(\d+)/ ) {
	    $chrA = $1; $bpA = $2; $chrB = $3; $bpB = $4;
	} else {
	    confess "Unexpected format for position: '$position'";
	}

	# Do first coordinate
	$start = $bpA - $buffer;
	$stop = $bpA + $buffer;
	my $chrFile = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36/Homo_sapiens.NCBI36.45.dna.chromosome.$chrA.fa";
	open(EXP, "expiece $start $stop $chrFile |") || confess "Could not open pipe for 'expiece $start $stop $chrFile'";
	@output = <EXP>;
	close EXP;
	foreach my $seq (@output) {
	    chomp $seq;
	    if ( $seq =~ />/ ) { 
		$seq =~ s/$remove//;
		$seq =~ s/fa from $start to $stop/$start.$stop/;
	    }
	    print OUT "$seq\n";
	}

	# Do second coordinate
	$start = $bpB - $buffer;
	$stop = $bpB + $buffer;
	$chrFile = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36/Homo_sapiens.NCBI36.45.dna.chromosome.$chrB.fa";
	open(EXP, "expiece $start $stop $chrFile |") || confess "Could not open pipe for 'expiece $start $stop $chrFile'";
	@output = <EXP>;
	close EXP;
	foreach my $seq (@output) {
	    chomp $seq;
	    if ( $seq =~ />/ ) { 
		$seq =~ s/$remove//;
		$seq =~ s/fa from $start to $stop/$start.$stop/;
	    }
	    print OUT "$seq\n";
	}


    } # matches 'foreach $position'
    close OUT;
}

sub samReadPassesFilter {
    # Input: $read in SAM format
    #        $maxMismatch
    #        $maxSoftClip 
    # Return: 1 if read has <= $maxMismatch and <= $maxSoftClip bases

    my ($read, $maxMismatch, $maxSoftClip) = @_;
    (defined $read && defined $maxMismatch && defined $maxSoftClip) || carp
	"Input parameter(s) not defined: '$read',  '$maxMismatch', '$maxSoftClip'";

    my $passesFilter = 1;

    # Mismatches
    if ( $read =~ /NM:i:(\d+)/ && $1 > $maxMismatch ) { $passesFilter = 0; }   
    # Softclip
    my (undef, undef, undef, undef, undef, $cigar) = split /\s+/, $read;
    if ( $cigar =~ /(\d+)S/ && $1 > $maxSoftClip ) { $passesFilter = 0; }
    if ( $cigar =~ /(\d+)S\w+\D(\d+)S/ && $1+$2 > $maxSoftClip ) { $passesFilter = 0; }

    return $passesFilter;
}

sub samReadCrossesBreakpoints {
    # Input: aligned $read in SAM format
    #        $start, $stop  -- region the read should cover (expressed in coordinates of $chr to which the read was aligned)
    # Return: 1 if read covers both coordinates.  It can't stop at a coordinate; it must extend by at least one base
    # The read must be mapped, not just it's mate
    
    my ($read, $start, $stop) = @_;
    (defined $read && defined $start && defined $stop) || carp
	"Input parameter(s) not defined: '$read', '$start', '$stop'";

    my ( $flag, $readStart, $readStop, $cigar, $seq );
    (undef, $flag, undef, $readStart, undef, $cigar, undef, undef, undef, $seq) = split /\s+/, $read;

    # Read should be mapped  0x0004 => the query sequence itself is unmapped
    if ( $flag & 0x0004) { return 0; }
    
    $readStop = $readStart + length($seq) - 1;

    return ( $readStart < $start && $readStop > $stop )
}

sub convertSamToFasta {
    # Input: ref to array of reads in SAM format
    #        File name for output
    #        Flag set to 1 if a quality file 'outFile.qual' should be written
    # Output: Fasta sequence where read names are "$name.$cigar.$flag"
    #         Quality file if flag set to 1
    

    my ( $readRef, $outFile, $writeQualityFile ) = @_;
    if ( !defined $writeQualityFile ) { $writeQualityFile = 0; }
    
    my ( $line, $name, $flag, $cigar, $seq, %allReadNames, $qualityString );
    open(FASTA, "> $outFile") || confess "Could not open '$outFile': $!";
    if ( $writeQualityFile ) { open(QUAL, "> $outFile.qual") || confess "Could not open '$outFile.qual': $!"; }
    foreach $line ( @{$readRef} ) {
	chomp $line;
	($name, $flag, undef, undef, undef, $cigar, undef, undef, undef, $seq, $qualityString) = split /\s+/, $line;

	# Make $name unique 
	$name = "$name.$cigar.$flag";
	( !defined $allReadNames{$name} ) ||
	    confess "Duplicate read name '$name'";
	$allReadNames{$name} = 1;
	print FASTA ">$name\n$seq\n";
	if ( $writeQualityFile ) {
	    $qualityString = fastqToPhred($qualityString);
	    print QUAL ">$name\n$qualityString\n";
	}
    }
}

sub fastqToPhred {
    # Convert fastq quality values to phred quality values
    my $qualityLine = $_[0];
    my $phredLine = "";
    foreach my $q (split //, $qualityLine) {
	my $quality = ord($q) - 33;
	$phredLine .= "$quality ";
    }
    return $phredLine;
}

sub runCrossMatch {
    # Input: query file, subject file, parameters (as string), optional output file
    # Return: ref to array of cross_match results.  Will also write to file if file is given

    my ( $query, $subject, $parameters, $outFile ) = @_;
    (-e $query) || confess "'$query' does not exist"; 
    (-e $subject) || confess "'$subject' does not exist";
    (defined $parameters) || confess "cross_match parameters are not defined";
    if ( !defined $outFile ) { $outFile = "/dev/null"; }
    
    
    open(CROSS, "cross_match $parameters $query $subject |") || 
	confess "Not able to start 'cross_match $parameters $query $subject'";
    my @output = <CROSS>;
    close CROSS;
    open(OUT, "> $outFile") || confess "Cold not open '$outFile': $!";
    print OUT "@output";
    close OUT;

    return \@output;
}


sub createHitObjects {
    # Input: either a file with cross_match results or ref to array of cross_match results
    # Return: ref to hash with key = query name; value = Hits object
    #   NOTE: only one hit is returned for each query.  It is the hit with the best score.
    
    my $input = $_[0];
    my ( @allCrossMatch, $line, $hit, $query, %hitList, );

    # Get array with all cross_match output
    if ( -e $input ) {
	open(IN, "< $input") || confess "Could not open '$input': $!";
	@allCrossMatch = <IN>;
	close IN;
    } else {
	@allCrossMatch = @{$input};
    }

    foreach $line ( @allCrossMatch ) {
	chomp $line;
	if ( $line =~ /$AlignmentLine/ ) {
	    $hit = new Hits;
	    $hit->addCrossMatchLine($line);
	    $query = $hit->queryName();
	    # It this query already has a hit, choose the one with the highest score
	    if ( !defined $hitList{$query} || $hit->score() > $hitList{$query}->score() ) {
		$hitList{$query} = $hit;
	    }
	}
    }

    return \%hitList;
}
 
sub crossMatchHitPassesFilter {
    # Input: Hits.pm object
    # Return: 1 if passes criteria

    my $hitObj = $_[0];
    if ( $hitObj->pastQueryEnd() > 5 || 
         $hitObj->queryStart() > 5 ||
         $hitObj->percentSubs() > 4 || 
         $hitObj->score() < 20 || 
         $hitObj->percentDels() > 3 ||
         $hitObj->percentInserts() > 3
        ) { return 0; }

    return 1;
}   

sub crossMatchHitCrossesBreakpoints {
    # Input: Hits.pm object, $start, $stop
    # Return: 1 if read covers both coordinates.  It can't stop at a coordinate; it must extend by at least one base

    ####  
    #  For the case where the read stops a few bases past a coordinate, the unaligned portion is relevant (pastQueryEnd and 
    #  queryStart)


    my ($hitObj, $start, $stop) = @_;
    # Make sure $start < $stop
    if ( $start > $stop ) { ($start, $stop) = ($stop, $start); }
    (defined $start && defined $stop && $start =~ /^\-?\d+$/ && $stop =~ /^\d+$/) ||
	confess "Expected integer start and stop";

    my $subjectStart = $hitObj->subjectStart();
    my $subjectEnd = $hitObj->subjectEnd();
    if ( $subjectStart > $subjectEnd ) { ($subjectStart, $subjectEnd) = ($subjectEnd, $subjectStart); }

    return ( $subjectStart < $start && $subjectEnd > $stop );

}

sub crossMatchHitsSimilar {
    # Input: Hits object to reference and Hit object to assembly
    #        The same read compared to two different targets
    # Used to compare alignment of read to reference and assembly contig
    #
    
}

sub uniqueCrossMatchAlignments {
    # Input: Ref to hash of Hits objects
    # Return: Ref to hash of Hits objects that have unique alignments.  If alignments are the
    #         same, one is arbitrarily chosen to represent all
    #         Key = query name, value = ref to Hits object
    # A hash is make where key is based on alignment line without the query name, value = alignment line
    # Then Hits objects are made from the unique alignments

    my $hitObjRef = $_[0];
    my (%newHitObjects, $line, @cols, $hashKey, %uniqueAlignments, $hit, );

    # This makes hash with key = alignment line without read name
    foreach my $id (keys %{$hitObjRef}) {
	$hashKey = "";
	$line = $$hitObjRef{$id}->alignmentLine();
	@cols = split /\s+/, $line;
	# The query name is in the 5th column ($i = 4)
	for (my $i = 0; $i <= $#cols; $i++ ) {
	    if ( $i != 4 ) { $hashKey .= "$cols[$i]\t"; }
	}
	$uniqueAlignments{$hashKey} = $line;
    }
			     
    # Now make a new hash of Hits objects
    foreach my $id ( keys %uniqueAlignments ) {
	$line = $uniqueAlignments{$id};
	($line =~ /$AlignmentLine/ ) || confess "'$line' is not an alignment line";
	$hit = new Hits;
	$hit->addCrossMatchLine($line);
	my $query = $hit->queryName();
	$newHitObjects{$query} = $hit;
    }

    return \%newHitObjects;

}

sub uniqueSamSequenceReads {
    # Input: ref to array of reads in SAM format
    # Return: ref to array of reads that have unique sequence
    # 
    #    NOTE: this ignores pairs so is not a good way to de-duplicate
    #    if aligner takes into account paired reads
    #    Essentially turns reads into fragment reads.  Just uses hash to 
    #    choose the last one of the unique sequences
    
    my $readRef = $_[0];
    my ( $line, %uniqueReads, @unique, $seq );
    foreach $line ( @{$readRef} ) {
	chomp $line;
	(undef, undef, undef, undef, undef, undef, undef, undef, undef, $seq) = split /\s+/, $line;
	$uniqueReads{$seq} = $line;
    }
    @unique = keys %uniqueReads;
    return \@unique;
}

return 1;
