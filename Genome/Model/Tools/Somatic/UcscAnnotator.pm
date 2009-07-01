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
            is_optional => 1,
            doc => "File of sites unable to be annotated",
            default => 'ucsc_unannotated_variants',
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
        %chrToRepeatmaskStatements, %statementsWithDescription, %statementsWithoutDescription,
        $table, $repeatMaskQuery, $scoresTableQuery, $start, $stop, $description, $chrStart, $chrStop,
        $namesTableQuery, $noScoreNameTableQuery, $exonCount, $exonStarts, $exonEnds, %chrToSelfChainStatements);


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
        ORDER BY genoStart";

        $chrToRepeatmaskStatements{$chr} = $dbh->prepare($repeatMaskQuery) ||
        die "Could not prepare statement '$repeatMaskQuery': $DBI::errstr \n";
    }
    #   Query for selfChain tables
    foreach my $chr (@available_chromosomes) {
        my $table = "chr$chr"."_chainSelf";
        my $selfChainQuery = "SELECT normScore, tStart, tEnd 
        FROM $table
        WHERE tEnd >= ? && tStart <= ?   
        ORDER BY tStart";

        $chrToSelfChainStatements{$chr} = $dbh->prepare($selfChainQuery) ||
        die "Could not prepare statement '$selfChainQuery': $DBI::errstr \n";
    }
    # Query with tables that have scores; Want to display the score in output
    foreach $table (@tablesWithScores) {
        # Query for tables that have score
        $scoresTableQuery = "SELECT score, chromStart, chromEnd
        FROM $table
        WHERE chrom = ? && chromEnd >= ? && chromStart <= ? 
        ORDER BY chromStart";


        $statementsWithDescription{$table} = $dbh->prepare($scoresTableQuery) ||
        die "Could not prepare statement '$scoresTableQuery': $DBI::errstr \n";
    }


    # Query for tfbsConsSites table, which uses zScore rather than score
    my $tfbsConsQuery = "SELECT zScore, chromStart, chromEnd
    FROM tfbsConsSites 
    WHERE chrom = ? && chromEnd >= ? && chromStart <= ? 
    ORDER BY chromStart";
    $statementsWithDescription{"tfbsConsSites"} = $dbh->prepare($tfbsConsQuery) ||
    die "Could not prepare statement '$tfbsConsQuery': $DBI::errstr \n"; 


    # Query for tables that do not have a score but have a 'name' field
    # Want to display the name instead of the score
    foreach $table (@tablesWithNames) {
        $namesTableQuery = "SELECT name, chromStart, chromEnd
        FROM $table
        WHERE chrom = ? && chromEnd >= ? && chromStart <= ? 
        ORDER BY chromStart";

        $statementsWithDescription{$table} = $dbh->prepare($namesTableQuery) ||
        die "Could not prepare statement '$namesTableQuery': $DBI::errstr \n";
    }

    # These tables have a variation type which is displayed
    foreach $table (@tablesWithvariationType) {
        my $query = "SELECT variationType, chromStart, chromEnd
        FROM $table
        WHERE chrom = ? && chromEnd >= ? && chromStart <= ? 
        ORDER BY chromStart"; 

        $statementsWithDescription{$table} = $dbh->prepare($query) ||
        die "Could not prepare statement '$namesTableQuery': $DBI::errstr \n";
    }

    # The table 'dgv' has 'varType' as column name rather than variationType
    my $query = "SELECT varType, chromStart, chromEnd
    FROM dgv
    WHERE chrom = ? && chromEnd >= ? && chromStart <= ?
    ORDER BY chromStart"; 
    $statementsWithDescription{"dgv"} = $dbh->prepare($query) ||
    die "Could not prepare statement '$namesTableQuery': $DBI::errstr \n";


    # The other tables do not have anything to display.  Just annotate with a '+'
    # if appropriate
    foreach $table (@tablesWithNeither) {
        #Query for tables that do not have score or name fields
        $noScoreNameTableQuery = "SELECT chromStart, chromEnd
        FROM $table
        WHERE chrom = ? && chromEnd >= ? && chromStart <= ? 
        ORDER BY chromStart";

        $statementsWithoutDescription{$table} = $dbh->prepare($noScoreNameTableQuery) ||
        die "Could not prepare statement '$noScoreNameTableQuery': $DBI::errstr \n";
    } 


    # Need special sub for recombRate.  Genome is divided into 1000000 bp windows.  Only get
    # rate in one window.  There are three values (avg, male, female) for three maps (Decode, Marshfield, 
    # Genethon).  Not all maps have a rate.  Ignore values of '0'
    my $recombinationQuery = "SELECT decodeAvg, marshfieldAvg, genethonAvg
    FROM recombRate
    WHERE chrom = ? && chromEnd >= ? && chromStart <= ?";
    my $recombinationStatement = $dbh->prepare($recombinationQuery) ||
    die "Could not prepare statement '$recombinationQuery': $DBI::errstr \n";

    # First print out the headers. This order MUST match the order in which the
    # statements are executed.
    print OUT "chr\tstart\tstop\tdecode,marshfield,genethon\trepeatMasker\tselfChain";
    #print OUT "chr\tstart\tstop\trepeatMasker";
    foreach $table ( sort keys %statementsWithDescription ) { print OUT "\t$table"; }
    foreach $table (sort keys %statementsWithoutDescription) { print OUT "\t$table"; }
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


        $gotEntry = 0; 
        # Repeatmasker query

        $chrToRepeatmaskStatements{$Chr}->execute($start, $stop) ||
        die("Could not execute statement for repeat masker table with ($start, $stop) for chromosome $Chr : $DBI::errstr \n");
        while ( ($description, $chrStart, $chrStop) =  $chrToRepeatmaskStatements{$Chr}->fetchrow_array() ) {
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
        $chrToSelfChainStatements{$Chr}->execute($start, $stop) || die "Could not execute statement for selfChain table with ($start, $stop): $DBI::errstr \n";
        while ( ($description, $chrStart, $chrStop) =  $chrToSelfChainStatements{$Chr}->fetchrow_array() ) {
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
        foreach $table (sort keys %statementsWithDescription) {
            $gotEntry = 0; %descriptionList = ();
            $statementsWithDescription{$table}->execute("chr$Chr", $start, $stop) ||
            die "Could not execute statement for table '$table' with ($Chr, $start, $stop): $DBI::errstr \n";
            while ( ($description, $chrStart, $chrStop) =  $statementsWithDescription{$table}->fetchrow_array() ) {
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
        foreach $table (sort keys %statementsWithoutDescription) {
            $gotEntry = 0; 
            $statementsWithoutDescription{$table}->execute("chr$Chr", $start, $stop) ||
            die "Could not execute statement for table '$table' with ($Chr, $start, $stop): $DBI::errstr \n";
            while ( ($chrStart, $chrStop) =  $statementsWithoutDescription{$table}->fetchrow_array() ) {
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

1;
