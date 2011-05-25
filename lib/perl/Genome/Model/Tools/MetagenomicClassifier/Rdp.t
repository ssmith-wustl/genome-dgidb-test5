#!/usr/bin/env perl

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
        metrics => 1,
);
ok($rdp, 'Created rdp classifier');
ok($rdp->execute, 'Execute rdp classifier');

# compare output
my $fh = eval{ Genome::Sys->open_file_for_reading($tmp_rdp_file); };
die "Failed to open classification file ($tmp_rdp_file): $@" if not $fh;
while ( my $line = $fh->getline ) {
    chomp $line;
    my ($seq_id) = split(/;/, $line);
    my ($match) = fgrep { /^>$seq_id/ } $fasta;
    cmp_ok($match->{count}, '==', 1, "Got an rdp output for seq ($seq_id)");
}
$fh->close;

# compare output
my $metrics_file = $tmp_rdp_file.'.metrics';
$fh = eval{ Genome::Sys->open_file_for_reading($tmp_rdp_file.'.metrics'); };
die "Failed to open metrics file ($metrics_file): $@" if not $fh;
my %metrics;
while ( my $line = $fh->getline ) {
    chomp $line;
    my ($key, $val) =split('=', $line);
    $metrics{$key} = $val;
}
$fh->close;
is_deeply(\%metrics, { total => 10, success => 10, error => 0, }, 'metrics match');

done_testing();
exit;

