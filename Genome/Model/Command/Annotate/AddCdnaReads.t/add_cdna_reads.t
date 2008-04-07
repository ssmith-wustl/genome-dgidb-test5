#!/gsc/bin/perl

use strict;
use warnings;

###############

package AddCdnaReads::Test;

use base 'Test::Class';

use Test::More;
use Test::Differences;
#use Test::Files;

sub execute : Tests
{
    my $self = shift;

    my $infile = 'ora50.dump.gge';
    my $infile_gm = 'ora50.dump.gge.gm';

	my $outfile = $infile.".read";
	my $outfile_gm = $infile_gm.".read";
	
    unlink $outfile_gm if -e $outfile_gm;
    unlink $outfile if -e $outfile;

    is((system "genome-model annotate add-cdna-reads --outfile $infile_gm --read-hash-cdna ../cDNA_unique_readcount_allcdna18.csv --read-hash-relapse-cdna ../cDNA_unique_readcount_allcdna18.csv --read-hash-unique-cdna ../cDNA_unique_readcount_allcdna18.csv --read-hash-unique-dna ../cDNA_unique_readcount_allcdna18.csv"), 0, "Executed");
 
    is((system "perl add_cdna_reads.pl $infile cDNA_unique_readcount_allcdna18.csv ../cDNA_unique_readcount_allcdna18.csv ../cDNA_unique_readcount_allcdna18.csv ../cDNA_unique_readcount_allcdna18.csv"), 0, "Executed");

    # check files
	open(SCRIPT_FILE, $outfile) or die "Could not open script output.";
	open(GM_FILE, $outfile_gm) or die "Could not open genome model output";
	my @script_file_contents = <SCRIPT_FILE>;
	my @gm_file_contents = <GM_FILE>;

	my $script_string = join(' ', @script_file_contents);
	my $gm_string = join(' ' , @gm_file_contents);
	
	eq_or_diff($script_string, $gm_string, "diff test");
    
    
    return 1;
}

#################

package main;

use Test::Class;

Test::Class->runtests(qw/ AddCdnaReads::Test /);

exit 0;

