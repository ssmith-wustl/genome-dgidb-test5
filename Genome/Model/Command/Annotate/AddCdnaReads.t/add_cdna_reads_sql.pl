#!/gsc/bin/perl

use strict;
use warnings;
se Carp;
use DBI;
use List::MoreUtils qw{ pairwise };
my $dbh = DBI->connect("dbi:SQLite:dbname=/tmp/add_cdna_orig.db","","", { RaiseError =>1, AutoCommit => 0});

#create tables
#my $read_hash_dna = 'genomic_counts';
#add_reads_count($dbh, $read_hash_dna, $ARGV[1]);
my $read_hash_unique_dna = 'genomic_unique_counts';
add_unique_reads_count($dbh, $read_hash_unique_dna, $ARGV[2]);
my $read_hash_cDNA = 'cDNA_counts';
add_reads_count($dbh, $read_hash_cDNA, $ARGV[3] );
my $read_hash_unique_cDNA = 'cDNA_unique_counts';
add_unique_reads_count($dbh, $read_hash_unique_cDNA, $ARGV[4] );
my $read_hash_relapse_cDNA = 'relapse_cDNA_counts';
add_reads_count($dbh, $read_hash_relapse_cDNA, $ARGV[5] );
my $read_hash_skin_dna = 'skin_read_counts';
add_reads_count($dbh, $read_hash_skin_dna, $ARGV[6] );
my $read_hash_unique_skin_dna = 'skin_unique_counts';
add_unique_reads_count($dbh, $read_hash_unique_skin_dna, $ARGV[7] );



open (IN, "<$ARGV[0]") or die "Can't open $ARGV[0]. $!";
  
open (OUT, ">$ARGV[0].$ARGV[1]") or die "Can't open $ARGV[0].$ARGV[1]. $!";
  
my @header = (  q{"dbSNP(0:no; 1:yes)"},
             q{"Gene_name"},
             q{"Chromosome"},
             q{"Start_position (B36)"},
             q{"End_position (B36)"},
             q{"Variant_allele"},
             q{"# of genomic reads supporting variant allele"},
             q{"# of cDNA reads supporting variant allele"},
             q{"# of skin genomic reads with variant allele"},
             q{"# of unique genomic reads supporting variant allele(starting point)"},
             q{"# of unique genomic reads supporting variant allele(context)"},
             q{"# of unique cDNA reads supporting variant allele(starting point)"},
             q{"# of unique cDNA reads supporting variant allele(context)"},
             q{"# of unique skin genomic reads with variant allele(starting point)"},
             q{"# of unique skin genomic reads with variant allele(context)"},
             q{"# of relapse cDNA reads supporting variant allele"},
             q{"Reference_allele"},
             q{"# of genomic reads supporting reference allele"},
             q{"# of cDNA reads supporting reference allele"},
             q{"# of skin genomic reads with reference allele"},
             q{"# of unique genomic reads supporting reference allele(starting point)"},
             q{"# of unique genomic reads supporting reference allele(context)"},
             q{"# of unique cDNA reads supporting reference allele(starting point)"},
             q{"# of unique cDNA reads supporting reference allele(context)"},
             q{"# of unique skin genomic reads with reference allele(starting point)"},
             q{"# of unique skin genomic reads with reference allele(context)"},
             q{"# of relapse cDNA reads supporting reference allele"},
             q{"Gene_expression"},
             q{"Detection"},
             q{"Ensembl_transcript_id"},
             q{"Transcript_stranding"},
             q{"Variant_type"},
             q{"Transcript_position"},
             q{"Amino_acid_change"},
             q{"Polyphen_prediction"},
             q{"submit(0:no; 1:yes)"},
         );
print OUT join(q{,}, @header), "\n";
while (<IN>) {
    chomp();
    my $line = $_;
    next if ( $line =~ /dbSNP/ );
    my (
        $dbsnp,      $gene,        $chromosome,     $start,
        $end,        $al1,         $al1_read_hg,    $al1_read_cDNA,
        $al2,        $al2_read_hg, $al2_read_cDNA,  $gene_exp,
        $gene_det,   $transcript,  $strand,         $trv_type,
        $c_position, $pro_str,     $pph_prediction, $submit,
      )
      = split(/,/);

    #grab read counts for genomic reads
#      (
#        $al1_read_hg,   $al2_read_hg,
#      )
#      = retrieve_readcount_from($dbh, $read_hash_dna, $chromosome,
#        $start, $al1, $al2, );
    #grab unique read counts for genomic reads
    my (
        $al1_read_unique_dna_start,   $al2_read_unique_dna_start,
        $al1_read_unique_dna_context, $al2_read_unique_dna_context,
      )
      = retrieve_unique_readcount_from($dbh, $read_hash_unique_dna, $chromosome,
        $start, $al1, $al2, );
    
    #grab cDNA readcounts
    ( $al1_read_cDNA, $al2_read_cDNA ) =
      retrieve_readcount_from($dbh, $read_hash_cDNA, $chromosome, $start, $al1,
        $al2 );

    #grab unique cDNA readcounts
    my (
        $al1_read_unique_cDNA_start,   $al2_read_unique_cDNA_start,
        $al1_read_unique_cDNA_context, $al2_read_unique_cDNA_context,
      )
      = retrieve_unique_readcount_from($dbh, $read_hash_unique_cDNA, $chromosome,
        $start, $al1, $al2, );

    #grab releapse readcounts
    my ( $al1_read_relapse_cDNA, $al2_read_relapse_cDNA ) =
      retrieve_readcount_from($dbh, $read_hash_relapse_cDNA,
        $chromosome, $start, $al1, $al2, );

    #grab skin readcounts
    my ( $al1_read_skin_dna, $al2_read_skin_dna ) =
      retrieve_readcount_from($dbh, $read_hash_skin_dna,
        $chromosome, $start, $al1, $al2, );
    
    my (
        $al1_read_unique_skin_start,   $al2_read_unique_skin_start,
        $al1_read_unique_skin_context, $al2_read_unique_skin_context,
      )
      = retrieve_unique_readcount_from($dbh, $read_hash_unique_skin_dna, $chromosome,
        $start, $al1, $al2, );
    my @fields = (  $dbsnp,
                    $gene,
                    $chromosome,
                    $start,
                    $end,
                    $al2,
                    $al2_read_hg,
                    $al2_read_cDNA,
                    $al2_read_skin_dna,
                    $al2_read_unique_dna_start,
                    $al2_read_unique_dna_context,
                    $al2_read_unique_cDNA_start,
                    $al2_read_unique_cDNA_context,
                    $al2_read_unique_skin_start,
                    $al2_read_unique_skin_context,
                    $al2_read_relapse_cDNA,
                    $al1,
                    $al1_read_hg,
                    $al1_read_cDNA,
                    $al1_read_skin_dna,
                    $al1_read_unique_dna_start,
                    $al1_read_unique_dna_context,
                    $al1_read_unique_cDNA_start,
                    $al1_read_unique_cDNA_context,
                    $al1_read_unique_skin_start,
                    $al1_read_unique_skin_context,
                    $al1_read_relapse_cDNA,
                    $gene_exp,
                    $gene_det,
                    $transcript,
                    $strand,
                    $trv_type,
                    $c_position,
                    $pro_str,
                    $pph_prediction,
                    $submit,
                );
    print OUT join(q{,}, @fields), "\n";
}


close(IN);
close(OUT);

  
print "final finished!\n";
$dbh->disconnect;
0;
#system("rm -rf /tmp/add_cdna.db");

sub retrieve_readcount_from {
    my ( $dbh, $tablename, $chromosome, $start, $al1, $al2 ) = @_;
    $al1 = lc $al1;
    $al2 = lc $al2;
    if($al1 !~ /a|c|t|g/ || $al2 !~ /a|c|t|g/) {
        return (0,0);
    }
    my $sql = qq{select $al1, $al2 from $tablename where chromosome='$chromosome' and position=$start};
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my @totals=(0,0);
    while(my @results = $sth->fetchrow_array) {
        if((scalar @results) == 2) {
            pairwise {$a += $b} @totals,@results; #sum in the results with th running total
        }
    }
    return @totals;
}

sub retrieve_unique_readcount_from {
    my ( $dbh, $tablename, $chromosome, $start, $al1, $al2 ) = @_;
    $al1 = lc $al1;
    $al2 = lc $al2;
    if($al1 !~ /a|c|t|g/ || $al2 !~ /a|c|t|g/) {
        return (0,0,0,0);
    }
    my $al1_c = $al1."_c";
    my $al2_c = $al2."_c";
    my $sql = qq{select $al1, $al2, $al1_c, $al2_c from $tablename where chromosome='$chromosome' and position=$start};
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my @totals=(0,0,0,0);

    while(my @results = $sth->fetchrow_array) {
        if((scalar @results) == 4) {
            pairwise {$a += $b} @totals,@results; #sum in the results with th running total
        }
    }
    return @totals;
}

sub add_unique_reads_count {
    my ($dbh, $tablename, $file) = @_;

    eval {
        local $dbh->{PrintError} = 0;
        $dbh->do(qq{DROP TABLE $tablename});
    };

    $dbh->do(qq{CREATE TABLE $tablename (chromosome TEXT, position INTEGER, a INTEGER, c INTEGER, g INTEGER, t INTEGER, a_c INTEGER, c_c INTEGER, g_c INTEGER, t_c INTEGER)});
    $dbh->commit();
    
	open (IN, "<$file") or die "Can't open $file. $!";
	my $line=<IN>; #read in header
    my $count = 0;
    while(<IN>){
        #skip inserted headers from cat
        next if /^chromosome.*$/xms;
        chomp();
        $count++;
        my ($chromosome,$pos,$a_reads,$c_reads,$g_reads,$t_reads,$a_reads_con,$c_reads_con,$g_reads_con,$t_reads_con) =split(/\t/);

        $dbh->do(qq{INSERT INTO $tablename VALUES ('$chromosome', $pos, $a_reads, $c_reads, $g_reads, $t_reads, $a_reads_con,$c_reads_con,$g_reads_con,$t_reads_con)});
        $dbh->commit if($count%10000 == 0);
    } 
    close(IN);
    my $index_name = $tablename."_index";
    $dbh->do(qq{CREATE INDEX $index_name ON $tablename(chromosome,position)});
    $dbh->commit();
    #IMPORT NOT WORKING
    #my $load_cmd = qq{sqlite3 -separator "\t" /tmp/add_cdna.db ".import $filename $tablename"};
    #system($load_cmd);
    
}

sub add_reads_count {
    my ($dbh, $tablename, $file) = @_;
    #From Perl Cookbook
    eval {
        local $dbh->{PrintError} = 0;
        $dbh->do(qq{DROP TABLE $tablename});
    };
    $dbh->do(qq{CREATE TABLE $tablename (chromosome TEXT, position INTEGER, a INTEGER, c INTEGER, g INTEGER, t INTEGER)});

    $dbh->commit();
    
    open (IN, "<$file") or die "Can't open $file. $!";
    my $count = 0;
    while(<IN>){
        $count++;
        chomp();
        my ($id,$chromosome,$pos,$ref_base,$ref_reads,$a_reads,$c_reads,$g_reads,$t_reads) =split(/\t/);
        $a_reads+=$ref_reads if($ref_base eq 'A' ||$ref_base eq 'N');
        $t_reads+=$ref_reads if($ref_base eq 'T' ||$ref_base eq 'N');
        $g_reads+=$ref_reads if($ref_base eq 'G' ||$ref_base eq 'N');
        $c_reads+=$ref_reads if($ref_base eq 'C' ||$ref_base eq 'N');
        $dbh->do(qq{INSERT INTO $tablename VALUES ('$chromosome', $pos, $a_reads, $c_reads, $g_reads, $t_reads)});
        $dbh->commit if($count%10000 == 0);
    }
    close(IN);
    my $index_name = $tablename."_index";
    $dbh->do(qq{CREATE INDEX $index_name ON $tablename(chromosome,position)});
    $dbh->commit();
}

