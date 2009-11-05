package Genome::Model::Tools::Somatic::UcscAnnotator;

use strict;
use warnings;
use Genome;
use Genome::Utility::HugoGene::HugoGeneMethods;
use Carp;
use IO::File;

class Genome::Model::Tools::Somatic::UcscAnnotator{
    is => 'Command',
    has => [
    input_file => {
        is  => 'String',
        is_input => 1,
        doc => 'The input file of variants to be annotated',
    },
    output_file => {
        is => 'Text',
        is_input => 1,
        is_output => 1,
        doc => "Store annotation in the specified file"
    },
    unannotated_file => {
        is => 'Text',
        is_input => 1,
        is_optional => 1,
        doc => "File of sites unable to be annotated",
        default => 'ucsc_unannotated_variants',
    },
    skip => {
        is => 'Boolean',
        default => '0',
        is_input => 1,
        is_optional => 1,
        doc => "If set to true... this will do nothing! Fairly useless, except this is necessary for workflow.",
    },
    skip_if_output_present => {
        is => 'Boolean',
        is_optional => 1,
        is_input => 1,
        default => 0,
        doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
    },
    ],
};

sub help_brief {
    "runs ucsc annotation on some variants",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools somatic ucsc-annotator...    
EOS
}

sub help_detail {                           
    return <<EOS 
runs ucsc annotation on some variants
EOS
}

sub execute {
    my $self = shift;
    $DB::single=1;

    if ($self->skip) {
        $self->status_message("Skipping execution: Skip flag set");
        return 1;
    }
    if (($self->skip_if_output_present)&&(-s $self->output_file)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    my $InputFile = $self->input_file;
    my $outfile = $self->output_file;

    # Default to the same name as output file with an extension if not specifically provided
    my $unannotated_file = $self->unannotated_file;
    $unannotated_file ||= $self->output_file . ".unannotated";

    open(UNANNOTATED, "> $unannotated_file") || die "Could not open '$unannotated_file': $!";

    open(OUT, "> $outfile") || die "Could not open '$outfile': $!";

    # Make look-up hash for UCSC gene name to Hugo gene name
    my $HugoGeneRef = Genome::Utility::HugoGene::HugoGeneMethods::makeHugoGeneObjects();
    my %UcscToHugo;
    foreach my $hugo ( keys %{$HugoGeneRef} ) {
        my $ucscName = $$HugoGeneRef{$hugo}->ucsc();
        if ( !defined $ucscName || $ucscName eq "" ) { next; }
        if ( defined $UcscToHugo{$ucscName} ) {
            print "WARNING: $ucscName => $hugo and $ucscName => $UcscToHugo{$ucscName} \n";
        }
        $UcscToHugo{$ucscName} = $hugo;
    }


    use DBI;
    my $db = "ucsc";
    my $user = "mgg_admin";
    my $password = "c\@nc3r"; 
    my $dataBase = "DBI:mysql:$db:mysql2";
    my $dbh = DBI->connect($dataBase, $user, $password) ||
    die "ERROR: Could not connect to database: $! \n";


    # The tables have slightly different entries.  The repeatmask tables 'chr$Chr_rmsk', 
    # knowGene, tfbsConsSites and recombRate tables are special cases.

    # use 'varType' for table 'dgv'  
    my ( @tablesWithScores, @tablesWithNames, @tablesWithNeither, $geneTableQuery, @tablesWithvariationType,
        %chrToRepeatmask, %queriesWithDescription, %queriesWithoutDescription,
        $table, $repeatMaskQuery, $scoresTableQuery, $start, $stop, $description, $chrStart, $chrStop,
        $namesTableQuery, $noScoreNameTableQuery, $exonCount, $exonStarts, $exonEnds, %chrToSelfChain);


    my %tableWithNoBin = ( cnpSebat2 => 1, cpgIslandExt => 1, gad => 1, knownGene => 1, recombRate => 1);   #keep track of which tables we cannot use binning on to speed up queries

    @tablesWithScores = qw ( delConrad2  eponine firstEF genomicSuperDups phastConsElements17way phastConsElements28way polyaDb polyaPredict simpleRepeat switchDbTss targetScanS  vistaEnhancers wgEncodeGisChipPet wgEncodeGisChipPetHes3H3K4me3 wgEncodeGisChipPetMycP493 wgEncodeGisChipPetStat1Gif wgEncodeGisChipPetStat1NoGif);

    @tablesWithvariationType = qw ( cnpLocke cnpSharp2 );  

    @tablesWithNames = qw (  cnpSebat2   cpgIslandExt gad  microsat );

    @tablesWithNeither = qw(cnpTuzun cnpRedon cnpIafrate2 encodeUViennaRnaz exaptedRepeats delHinds2 delMccarroll uppsalaChipH3acSignal uppsalaChipUsf1Signal uppsalaChipUsf2Signal wgEncodeUcsdNgTaf1Signal wgEncodeUcsdNgTaf1ValidH3K4me wgEncodeUcsdNgTaf1ValidH3ac wgEncodeUcsdNgTaf1ValidRnap wgEncodeUcsdNgTaf1ValidTaf oreganno regPotential7X laminB1 );


    # Query for gene table.  Call with $chr, $start, $end
    $geneTableQuery = "SELECT name, txStart, txEnd, exonCount, exonStarts, exonEnds
    FROM knownGene
    WHERE chrom = ? && txEnd >= ? && txStart <= ?
    ORDER BY txStart";
    my $geneStatement = $dbh->prepare($geneTableQuery) ||
    die "Could not prepare statement '$geneTableQuery': $DBI::errstr \n";
    $DB::single =1 ;
    
    # Define available chromosomes for repeatmasker to use
    my @available_chromosomes = (1..22, "X","Y");

    #  Query for repeatmask tables.  Call with start, end of region to check
    #  Call with $chrToRepeatmaskStatements{$chr}->execute($start, $stop)
    foreach my $chr (@available_chromosomes) {
        $table = "chr$chr"."_rmsk";
        $repeatMaskQuery = "SELECT repFamily, genoStart, genoEnd 
        FROM $table
        WHERE genoEnd >= ? && genoStart <= ?   
        AND %s
        ORDER BY genoStart";

        $chrToRepeatmask{$chr} = $repeatMaskQuery;
    }
    #   Query for selfChain tables
    foreach my $chr (@available_chromosomes) {
        my $table = "chr$chr"."_chainSelf";
        my $selfChainQuery = "SELECT normScore, tStart, tEnd 
        FROM $table
        WHERE tEnd >= ? && tStart <= ?   
        AND %s
        ORDER BY tStart";

        $chrToSelfChain{$chr} = $selfChainQuery;    
    }
    
    # Query with tables that have scores; Want to display the score in output
    # To handle binning we will not include it in the string
    foreach $table (@tablesWithScores) {
        # Query for tables that have score
        $scoresTableQuery = "SELECT score, chromStart, chromEnd
        FROM $table
        WHERE chrom = ? && chromEnd >= ? && chromStart <= ? 
        AND %s
        ORDER BY chromStart";

        $queriesWithDescription{$table} = $scoresTableQuery;
    }


    # Query for tfbsConsSites table, which uses zScore rather than score
    my $tfbsConsQuery = "SELECT zScore, chromStart, chromEnd
    FROM tfbsConsSites 
    WHERE chrom = ? && chromEnd >= ? && chromStart <= ? 
    AND %s
    ORDER BY chromStart";
    $queriesWithDescription{"tfbsConsSites"} = $tfbsConsQuery;  


    # Query for tables that do not have a score but have a 'name' field
    # Want to display the name instead of the score
    foreach $table (@tablesWithNames) {
        $namesTableQuery = "SELECT name, chromStart, chromEnd
        FROM $table
        WHERE chrom = ? && chromEnd >= ? && chromStart <= ? 
        AND %s
        ORDER BY chromStart";

        $queriesWithDescription{$table} = $namesTableQuery;
    }

    # These tables have a variation type which is displayed
    foreach $table (@tablesWithvariationType) {
        my $query = "SELECT variationType, chromStart, chromEnd
        FROM $table
        WHERE chrom = ? && chromEnd >= ? && chromStart <= ? 
        AND %s
        ORDER BY chromStart"; 

        $queriesWithDescription{$table} = $query;
    }

    # The table 'dgv' has 'varType' as column name rather than variationType
    my $query = "SELECT varType, chromStart, chromEnd
    FROM dgv
    WHERE chrom = ? && chromEnd >= ? && chromStart <= ?
    AND %s
    ORDER BY chromStart"; 
    $queriesWithDescription{"dgv"} = $query;


    # The other tables do not have anything to display.  Just annotate with a '+'
    # if appropriate
    foreach $table (@tablesWithNeither) {
        #Query for tables that do not have score or name fields
        $noScoreNameTableQuery = "SELECT chromStart, chromEnd
        FROM $table
        WHERE chrom = ? && chromEnd >= ? && chromStart <= ? 
        AND %s
        ORDER BY chromStart";

        $queriesWithoutDescription{$table} = $noScoreNameTableQuery;
    } 


    # Need special sub for recombRate.  Genome is divided into 1000000 bp windows.  Only get
    # rate in one window.  There are three values (avg, male, female) for three maps (Decode, Marshfield, 
    # Genethon).  Not all maps have a rate.  Ignore values of '0'
    #
    # This does not support bins. Leaving alonge
    my $recombinationQuery = "SELECT decodeAvg, marshfieldAvg, genethonAvg
    FROM recombRate
    WHERE chrom = ? && chromEnd >= ? && chromStart <= ?";
    my $recombinationStatement = $dbh->prepare($recombinationQuery) ||
    die "Could not prepare statement '$recombinationQuery': $DBI::errstr \n";

    # First print out the headers. This order MUST match the order in which the
    # statements are executed.
    print OUT "chr\tstart\tstop\tdecode,marshfield,genethon\trepeatMasker\tselfChain";
    #print OUT "chr\tstart\tstop\trepeatMasker";
    foreach $table ( sort keys %queriesWithDescription ) { print OUT "\t$table"; }
    foreach $table (sort keys %queriesWithoutDescription) { print OUT "\t$table"; }
    print OUT "\tknownGenes\tHUGO symbol\n";


    open(IN, "< $InputFile") ||
    die "Could not open '$InputFile': $!";
    my @entireFile = <IN>;
    close IN;
    my ($gotEntry, %descriptionList, );
    
    foreach my $line (@entireFile) {
        $DB::single=1;
        chomp $line;
        my ($Chr, $start, $stop) = split /\s+/, $line;

        #check if we can annotate this site
        unless(grep {$Chr eq $_} @available_chromosomes) {
            warn "Unable to annotate $Chr\t$start\t$stop. Chromosome unavailable for annotation\n";
            print UNANNOTATED "$Chr\t$start\t$stop\n"; 
            next;
        }

        print OUT "$Chr\t$start\t$stop\t"; 
        $start = $start - 1; #change to 0 based
        $stop = $stop - 1; #change to 0 based
        $gotEntry = 0; %descriptionList = ();


        # Recombination query
        $recombinationStatement->execute("chr$Chr", $start, $start) ||
        die "Could not execute statement for repeat masker table with ($start, $stop): $DBI::errstr \n";
        while ( my ($decode, $marsh, $genethon) = $recombinationStatement->fetchrow_array() ) {
            if ( $decode == 0 ) { $decode = "-"; }
            if ( $marsh == 0 ) { $marsh = "-"; }
            if ( $genethon == 0 ) { $genethon = "-"; }
            print OUT "$decode $marsh $genethon ";
            $gotEntry = 1;
        }
        if ( !$gotEntry ) { print OUT "- - -"; }
        print OUT "\t";
        my $bin_string = $self->bin_query_string($start,$stop);

        $gotEntry = 0; 
        # Repeatmasker query
        my $repeatMaskQueryString = sprintf($chrToRepeatmask{$Chr},$bin_string); 
        my $repeat_statement = $dbh->prepare_cached($repeatMaskQueryString) ||
        die "Could not prepare statement '$repeatMaskQueryString': $DBI::errstr \n";

        $repeat_statement->execute($start,$stop);
       


        #$chrToRepeatmaskStatements{$Chr}->execute($start, $stop) ||
        #die("Could not execute statement for repeat masker table with ($start, $stop) for chromosome $Chr : $DBI::errstr \n");
#        while ( ($description, $chrStart, $chrStop) =  $chrToRepeatmaskStatements{$Chr}->fetchrow_array() ) {
        while ( ($description, $chrStart, $chrStop) =  $repeat_statement->fetchrow_array() ) {
        
            $descriptionList{$description} = 1;
            $gotEntry = 1;
        }
        if ( $gotEntry ) { 
            foreach (keys %descriptionList) { print OUT "$_ "; }
        } else {
            print OUT  "-"; 
        }
        print OUT  "\t";

        # selfChain query
        %descriptionList = ();
        $gotEntry = 0;

        
        my $selfChainQueryString = sprintf($chrToSelfChain{$Chr}, $bin_string); 
        
        my $self_chain_statement = $dbh->prepare_cached($selfChainQueryString) ||
        die "Could not prepare statement '$selfChainQueryString': $DBI::errstr \n";

        $self_chain_statement->execute($start,$stop);

        #$chrToSelfChainStatements{$Chr}->execute($start, $stop) || die "Could not execute statement for selfChain table with ($start, $stop): $DBI::errstr \n";
        while ( ($description, $chrStart, $chrStop) =  $self_chain_statement->fetchrow_array() ) {
            $descriptionList{$description} = 1;
            $gotEntry = 1;
        }
        if ( $gotEntry ) { 
            foreach (keys %descriptionList) { print OUT "$_ "; }
        } else {
            print OUT  "-"; 
        }
        print OUT  "\t";

        # Tables that have a description or score
        foreach $table (sort keys %queriesWithDescription) {
            $gotEntry = 0; %descriptionList = ();
            my $queryString = sprintf($queriesWithDescription{$table}, exists($tableWithNoBin{$table}) ? "1" : $bin_string);
            my $statement = $dbh->prepare_cached($queryString) ||
            die "Could not prepare statement '$queryString': $DBI::errstr \n";

            $statement->execute("chr$Chr", $start, $stop) ||
            die "Could not execute statement for table '$table' with ($Chr, $start, $stop): $DBI::errstr \n";
            while ( ($description, $chrStart, $chrStop) =  $statement->fetchrow_array() ) {
                if ( $description eq "" ) { next; }
                $descriptionList{$description} = 1;
                $gotEntry = 1;
            }
            if ( $gotEntry ) { 
                foreach (keys %descriptionList) { print OUT "$_ "; }
            } else {
                print OUT "-"; 
            }
            print OUT "\t";
        }


        # Tables that are annotated with either a '+' or '-'
        foreach $table (sort keys %queriesWithoutDescription) {
            $gotEntry = 0; 
            my $queryString = sprintf($queriesWithoutDescription{$table}, exists($tableWithNoBin{$table}) ? "1" : $bin_string);
            my $statement = $dbh->prepare_cached($queryString) ||
            die "Could not prepare statement '$queryString': $DBI::errstr \n";
            $statement->execute("chr$Chr", $start, $stop) ||
            die "Could not execute statement for table '$table' with ($Chr, $start, $stop): $DBI::errstr \n";
            while ( ($chrStart, $chrStop) =  $statement->fetchrow_array() ) {
                # Only print out one '+' even if there are several entries that overlap
                if ( !$gotEntry ) { print OUT "+"; }
                $gotEntry = 1;
            }
            if ( !$gotEntry ) { print OUT  "-"; }
            print OUT "\t";
        }   

        # Genes in regions
        $gotEntry = 0;
        my (@hugoNames, $exon);
        $geneStatement->execute("chr$Chr", $start, $stop) ||
        die "Could not execute statement for table '$table' with ($Chr, $start, $stop): $DBI::errstr \n";
        while ( ($description, $chrStart, $chrStop, $exonCount, $exonStarts, $exonEnds) = $geneStatement->fetchrow_array() ) {
            print OUT "$description ";
            if ( defined $UcscToHugo{$description} ) { push @hugoNames, $UcscToHugo{$description}; }
            $gotEntry = 1;
            $exon = $self->regionOverlapsExons($start, $stop, $exonCount, $exonStarts, $exonEnds);
            if ( $exon ) { print OUT " $exon "
            }
        }
        if ( !$gotEntry ) { print OUT "-\t-"; }
        print OUT "\t";
        if ( scalar(@hugoNames) >= 1 ) { print OUT "@hugoNames"; } else { print OUT "-"; }
        print OUT "\n";

    }

    $dbh->disconnect();
}

# Returns "exonNumber start stop"  if one of the region overlaps one of the exons
# 0 if not
sub regionOverlapsExons {
    my $self = shift;
    my ($start, $end, $exonCount, $exonStarts, $exonEnds) = @_;

    my ( @starts, @ends, );
    @starts =  split /,/, $exonStarts;
    @ends = split /,/, $exonEnds;
    ( scalar(@starts) == $exonCount && scalar(@ends) == $exonCount ) ||
    confess "Did not get expected number of exons";
    for ( my $i = 0; $i <= $#starts; $i++ ) {
        if ( $ends[$i] >= $start && $starts[$i] <= $end ) {
            my $num = $i + 1; 
            my $exon = " Exon $num $starts[$i] $ends[$i] ";
            return $exon;
        }
    }
    return 0;
}

sub calculate_bin_from_range {
    my ($self, $start, $end) = @_;
    #This code derived from C code from http://genomewiki.ucsc.edu/index.php/Bin_indexing_system

    #This file is copyright 2002 Jim Kent, but license is hereby
    #granted for all use - public, private or commercial. */

    # add one new level to get coverage past chrom sizes of 512 Mb
    #      effective limit is now the size of an integer since chrom start
    #      and end coordinates are always being used in int's == 2Gb-1
    my @binOffsetsExtended = (4096+512+64+8+1, 512+64+8+1, 64+8+1, 8+1, 1, 0);
    my $_binFirstShift =  17;       # How much to shift to get to finest bin.
    my $_binNextShift = 3;          # How much to shift to get to next larger bin.
    my $_binOffsetOldToExtended = 4681;

    # Given start,end in chromosome coordinates assign it
    # a bin.   There's a bin for each 128k segment, for each
    # 1M segment, for each 8M segment, for each 64M segment,
    # for each 512M segment, and one top level bin for 4Gb.
    #      Note, since start and end are int's, the practical limit
    #      is up to 2Gb-1, and thus, only four result bins on the second
    #      level.
    # A range goes into the smallest bin it will fit in. */
    my ($startBin, $endBin) = ($start, $end-1);
    $startBin >>= $_binFirstShift;
    $endBin >>= $_binFirstShift;
    for (my $i = 0; $i < scalar(@binOffsetsExtended); $i++) {
        if ($startBin == $endBin) {
            return $_binOffsetOldToExtended + $binOffsetsExtended[$i] + $startBin;
            $startBin >>= $_binNextShift;
            $endBin >>= $_binNextShift;
        }
        $self->error_message(sprintf("start %d, end %d out of range in calculate_bin_from_range (max is 2Gb)", $start, $end));
        return 0;
    }
}

sub bin_query_string {
    my ($self, $start, $end) = @_;  #start and end should probably be 0 based as UCSC is 0 based
    #This code taken from function in kent src tree of UCSC called static void hAddBinToQueryStandard(char *binField, int start, int end, struct dyString *query, boolean selfContained)
    #Found this online at http://code.google.com/p/genomancer/source/browse/trunk/poka/src/genomancer/ucsc/das2/BinRange.java?spec=svn66&r=66 and haven't bothered to look in the actual source
    my ($bFirstShift, $bNextShift) = (17,3);
    my $startBin = ($start>>$bFirstShift);
    my $endBin = (($end)>>$bFirstShift);#TODO figure out if the -1 is necessary
    my @binOffsets = ( 512+64+8+1, 64+8+1, 8+1, 1, 0); #Not using the extended binning scheme...
    my $_binOffsetOldToExtended = 4681;

    my $bin_query_string = "(";
    for (my $i = 0; $i < scalar(@binOffsets); ++$i) {
        my $offset = $binOffsets[$i];
        if ($i != 0) {
            $bin_query_string .=  " or ";
        }
        if ($startBin == $endBin) {
            #assuming the binField is actually bin in all cases (may not be true?)
            $bin_query_string .= sprintf("%s=%u", "bin", $startBin + $offset);
        }
        else {
            $bin_query_string .= sprintf("( %s>=%u and %s<=%u )", "bin", $startBin + $offset, "bin", $endBin + $offset);
        }
        $startBin >>= $bNextShift;
        $endBin >>= $bNextShift;
    }
    $bin_query_string .= sprintf(" or %s=%u )", "bin", $_binOffsetOldToExtended);
    return $bin_query_string;
}



1;
