#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Compare;
use POSIX;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

BEGIN {
    my $archos = POSIX::uname;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from a 64-bit machine";
    } else {
        plan tests => 6;
    }
    use_ok( 'Genome::Model::Tools::Validation::CountContigs');
};

#The following are just tests I set up to determine the code was functioning correctly. More tests would be good for edge cases and any dependencies.
my $fake_read_seq = "ACTATCG";
my $fake_read_pos = 228;
my $fake_cigar = "3M1D4M";

my $spans_range = Genome::Model::Tools::Validation::CountContigs->_spans_range(228,230,$fake_read_pos, $fake_cigar);
ok(defined $spans_range);
$spans_range = Genome::Model::Tools::Validation::CountContigs->_spans_range(228,231,$fake_read_pos, $fake_cigar);
ok(!defined $spans_range);
$spans_range = Genome::Model::Tools::Validation::CountContigs->_spans_range(227,228,$fake_read_pos, $fake_cigar);
ok(!defined $spans_range);
$spans_range = Genome::Model::Tools::Validation::CountContigs->_spans_range(232,234,$fake_read_pos, $fake_cigar);
ok(defined $spans_range);
$spans_range = Genome::Model::Tools::Validation::CountContigs->_spans_range(232,237,$fake_read_pos, $fake_cigar);
ok(!defined $spans_range);
