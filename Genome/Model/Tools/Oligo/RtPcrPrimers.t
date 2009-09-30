#!/gsc/bin/perl

use strict;
use warnings;
use IPC::Run;

use above "Genome";
use Test::More tests => 3;

use_ok('Genome::Model::Tools::Oligo::RtPcrPrimers');


#my @command = ["gmt" , "oligo" , "pcr-primers" , "-fasta" , "$fasta" , "-output-dir" , "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Oligo-PcrPrimers" , "-display-blast" , "-note" , "$note"];

my @command = ["gmt" , "oligo" , "rt-pcr-primers" , "-chr" , "15" , "-target-pos" , "72102230" , "-transcript" , "NM_033238" , "-pcr-primer-options" , "-blast-db /gscmnt/sata147/info/medseq/rmeyer/resources/HS36Transcriptome/new_masked_ccds_ensembl_genbank_utr_nosv_all_transcriptome_quickfix.fa -primer3-defaults" , "-include-exon"];

&ipc_run(@command);

ok (-e "PML.NM_033238.15.72102230.ordered_primer_pairs.txt");
ok (-e "PML.NM_033238.15.72102230.txt");
system qq(rm PML.NM_033238.15.72102230.*);

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
