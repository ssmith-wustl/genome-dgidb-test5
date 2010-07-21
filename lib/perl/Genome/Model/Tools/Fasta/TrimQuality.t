#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 11;
use File::Compare;
use File::Temp;
use File::Copy;

BEGIN {
        use_ok ('Genome::Model::Tools::Fasta::TrimQuality');
}

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fasta/TrimQuality';
ok(-d $dir, "Test dir ($dir) exists");
my $fasta = $dir .'/test.fasta';
ok(-f $fasta, "Fasta ($fasta) exists");
my $qual = $fasta .'.qual';
ok(-f $qual, "Qual ($qual) exists");

# Should work
my $trim1 = Genome::Model::Tools::Fasta::TrimQuality->create(
    fasta_file => $fasta,
    min_trim_quality => 10,
    min_trim_length  => 100,
);
ok($trim1->execute, "trim1 finished ok");

reset_file($fasta, $qual, $dir);

# No fasta
ok(
    ! Genome::Model::Tools::Fasta::TrimQuality->create(
        fasta_file => $dir.'/no.fasta',
        min_trim_quality => 12,
        min_trim_length  => 80,
    ),
    "This supposed to fail because of no fasta",
);

# No qual for fasta 
ok(
    ! Genome::Model::Tools::Fasta::TrimQuality->create(
        fasta_file => $dir.'/test.no_qual.fasta',
        min_trim_quality => 12,
        min_trim_length  => 80,
    ),
    "This supposed to fail because of no quality file",
);

my $trim4 = Genome::Model::Tools::Fasta::TrimQuality->create(
    fasta_file => $fasta,
);

ok($trim4->execute, "trim4 running ok");
is(compare("$dir/test.fasta.ori.clip", $fasta),0, "using default, fasta is ok");
cmp_ok(compare("$dir/test.fasta.qual.ori.clip", $qual),'==', 0, "using default, qual is ok");

reset_file($fasta, $qual, $dir);

my $trim5 = Genome::Model::Tools::Fasta::TrimQuality->create(
    fasta_file       => $fasta,
    min_trim_length => 'hello',
);

#eval(my $rv = $trim5->execute);
#print $rv;
ok(!$trim5->execute, "This supposed to fail because trim5 uses non-integer as min_trim_length");

reset_file($fasta, $qual, $dir);

exit;

sub reset_file {
    my ($fasta, $qual, $dir) = @_;
    unlink $fasta;
    unlink $qual;
    unlink "$fasta.preclip";
    unlink "$qual.preclip";

    copy "$dir/test.fasta.ori", $fasta;
    copy "$dir/test.fasta.qual.ori", $qual;

    return;
};

