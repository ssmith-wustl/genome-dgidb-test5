#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use File::Grep 'fgrep';
require File::Temp;
use Test::More;

use_ok('Genome::Model::Tools::MetagenomicClassifier::Rdp') or die;

# tmp output dir and file
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
ok(-d $tmpdir, 'created tmp dir');
my $tmp_rdp_file = $tmpdir.'/U_PR-JP_TS1_2PCA.fasta.rdp';
my $fasta = '/gsc/var/cache/testsuite/data/Genome-Utility-MetagenomicClassifier/U_PR-JP_TS1_2PCA.fasta';
ok(-s $fasta, 'Test fasta exists');

# create and execute
my $rdp = Genome::Model::Tools::MetagenomicClassifier::Rdp->create(
        input_file => $fasta,
        output_file => $tmp_rdp_file,
        training_set => 'broad',
        version => '2x1',
);
ok($rdp, 'Created rdp classifier');
ok($rdp->execute, 'Execute rdp classifier');

# compare output
my $fh = Genome::Sys->open_file_for_reading($tmp_rdp_file)
    or die;
while ( my $line = $fh->getline ) {
    chomp $line;
    my ($seq_id) = split(/;/, $line);
    my ($match) = fgrep { /^>$seq_id/ } $fasta;
    cmp_ok($match->{count}, '==', 1, "Got an rdp output for seq ($seq_id)");
}
$fh->close;

done_testing();
exit;

