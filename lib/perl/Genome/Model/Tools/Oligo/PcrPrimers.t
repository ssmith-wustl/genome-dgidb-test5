#!/gsc/bin/perl

use strict;
use warnings;
use IPC::Run;

use above "Genome";
use Test::More tests => 3;

use_ok('Genome::Model::Tools::Oligo::PcrPrimers');

my $fasta = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Oligo-PcrPrimers/10_126009344.c1.refseq.fasta";
#my $fasta = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Oligo-PcrPrimers/10_126009344.c1.refseq.fasta.test";

ok (-e $fasta);

my $note = "Chr10:126009344";
#system qq(gmt oligo pcr-primers -fasta $fasta -output-name pcrprimer_test);

#my @command = ["gmt" , "oligo" , "pcr-primers" , "-fasta" , "$fasta" , "-output-name" , "pcrprimer_test" , "-output-dir" , "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Oligo-PcrPrimers" , "-keep-blast"];
my @command = ["gmt" , "oligo" , "pcr-primers" , "-fasta" , "$fasta" , "-output-dir" , "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Oligo-PcrPrimers" , "-display-blast" , "-note" , "$note" , "-primer3-defaults" , "-header" , "Target"];

&ipc_run(@command);

ok (-e "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Oligo-PcrPrimers/chr10:126009460.1116.ordered_primer_pairs.txt");
system qq(rm /gsc/var/cache/testsuite/data/Genome-Model-Tools-Oligo-PcrPrimers/chr10:126009460.1116.ordered_primer_pairs.txt /gsc/var/cache/testsuite/data/Genome-Model-Tools-Oligo-PcrPrimers/chr10:126009460.1116.primer3.result.txt);


sub ipc_run {

    my (@command) = @_;
    my ($in, $out, $err);
    IPC::Run::run(@command, \$in, \$out, \$err);
    if ($err) {
#	print qq($err\n);
    }
    if ($out) {
#	print qq($out\n);
    }
}
