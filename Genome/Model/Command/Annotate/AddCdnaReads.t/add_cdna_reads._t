#!/gsc/bin/perl

use strict;
use warnings;

###############

package AddCdnaReads::Test;

use base 'Test::Class';

use Test::More;
use Test::Differences;
#use Test::Files;
use Tie::File;

sub execute : Tests
{
    my $self = shift;

    my $in = 'report';

    # run genome model command
    is((system "genome-model annotate add-cdna-reads --input report --tumor-unique /gscmnt/sata180/info/medseq/dlarson/amll123t100_readcounts/amll123t100_unique-q1/amll123t100_unique-q1_allchr.merge --tumor-cdna-raw /gscmnt/sata180/info/medseq/dlarson/amll123t100_readcounts/amll123t100_cdna_readcount-q1/cDNA_readcount_amll123t100.csv --tumor-cdna-unique /gscmnt/sata180/info/medseq/dlarson/amll123t100_readcounts/amll123t100_cdna_unique_readcount-q1/cDNA_unique_readcount_amll123t100.csv --relapse-cdna-raw /gscmnt/sata180/info/medseq/llin/cDNA_relapse_readcount/maq_readcount_cDNA_relapse_amll123t100.q1r07t096_new.csv --skin-raw /gscmnt/sata183/info/medseq/kchen/Hs_build36/maq6/analysis_skin/amll123skin34_100/amll123skin34_chr.merge.csv --skin-unique /gscmnt/sata183/info/medseq/kchen/Hs_build36/maq6/analysis_skin/amll123skin34_unique100/amll123skin34_unique_chr.merge.csv --rebuild-database 1"), 256, "Executed"); 
    
	# run original script
    is((system "perl add_cdna_reads_sql.pl report old /gscmnt/sata180/info/medseq/dlarson/amll123t100_readcounts/amll123t100_unique-q1/amll123t100_unique-q1_allchr.merge /gscmnt/sata180/info/medseq/dlarson/amll123t100_readcounts/amll123t100_cdna_readcount-q1/cDNA_readcount_amll123t100.csv /gscmnt/sata180/info/medseq/dlarson/amll123t100_readcounts/amll123t100_cdna_unique_readcount-q1/cDNA_unique_readcount_amll123t100.csv /gscmnt/sata180/info/medseq/llin/cDNA_relapse_readcount/maq_readcount_cDNA_relapse_amll123t100.q1r07t096_new.csv /gscmnt/sata183/info/medseq/kchen/Hs_build36/maq6/analysis_skin/amll123skin34_100/amll123skin34_chr.merge.csv /gscmnt/sata183/info/medseq/kchen/Hs_build36/maq6/analysis_skin/amll123skin34_unique100/amll123skin34_unique_chr.merge.csv"), 0, "Executed");

	# check that both files have 40 rows and have the same output
    my $gm_file = "$in" . ".add";
    tie(my @sort, 'Tie::File', $gm_file);
    is(scalar(@sort), 40, "Sorted output file ($gm_file) has 40 lines")
        or die;
    
    my $comp_file = "$in" . ".old";
    tie(my @comp, 'Tie::File', $comp_file);
    is(scalar(@comp), 40, "Comparison file ($comp_file) has 40 lines")
        or die;

    is_deeply(\@sort, \@comp, 'Compared new and old output');
 
    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ AddCdnaReads::Test /);

exit 0;

