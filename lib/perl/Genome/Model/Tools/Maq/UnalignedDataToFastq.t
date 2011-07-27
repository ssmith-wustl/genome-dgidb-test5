#!/usr/bin/env perl
use above "Genome";
use Genome::Sys;
use Test::More tests => 6;
use FindBin q($Bin);

use_ok("Genome::Model::Tools::Maq::UnalignedDataToFastq");

my $tmp = Genome::Sys->create_temp_directory(CLEANUP => 1);
#$tmp = '.';

my $expected_base = $Bin . '/UnalignedDataToFastq.t';
my $actual_base = $tmp . '/file';

my $in = $expected_base . '.in';

my $expected1_1 = $expected_base . '.out1.1';
my $actual1_1 = $actual_base . '.actual1.1';

my $expected1_2 = $expected_base . '.out1.2';
my $actual1_2 = $actual_base . '.actual1.2';

my $rv = undef;
eval {
    $rv = Genome::Model::Tools::Maq::UnalignedDataToFastq->execute(
        in => $in,
        fastq => $actual1_1,
        reverse_fastq => $actual1_2,
    )
};

ok($rv, 'conversion executed for paired-end data');
compare($actual1_1,$expected1_1);
compare($actual1_2,$expected1_2);


my $expected2 = $expected_base . '.out2';
my $actual2 = $actual_base. '.out2';

$rv = undef;
eval {
    $rv = Genome::Model::Tools::Maq::UnalignedDataToFastq->execute(
        in => $in,
        fastq => $actual2,
    )
};

ok($rv, 'conversion executed for fragment data');
compare($actual2,$expected2);

sub compare {
    my ($f1,$f2,$msg) = @_;
    unless ($msg) {
        $msg = "file $f1 matches file $f2";
    }
    unless (-e $f1 and -e $f2) {
        if (! -e $f1) {
            diag("file $f1 is missing");
        }
        if (! -e $f2) {
            diag("file $f2 is missing");
        }
        ok(0,$msg);
    }
    my $diff = `diff '$f1' '$f2'`;
    ok($diff eq '', $msg)
        or diag($diff);
}

