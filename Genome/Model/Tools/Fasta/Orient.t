#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 13;
use File::Compare;
use File::Temp;
use File::Basename;
use Bio::SeqIO;

BEGIN {
        use_ok ('Genome::Model::Tools::Fasta::Orient')
            or die;
}

#< Test if it really works >#
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fasta-Orient';
my $fasta    = $dir.'/assembled.fasta';
my $qual     = $dir.'/assembled.fasta.qual';
my $s_fasta  = $dir.'/primers_sense.fasta';
my $as_fasta = $dir.'/primers_anti_sense.fasta';

my $orient = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file       => $fasta,
    sense_fasta_file => $s_fasta,
    anti_sense_fasta_file => $as_fasta,
);

my $confirmed_fasta_file = $orient->confirmed_fasta_file;
my $confirmed_qual_file  = $orient->confirmed_qual_file;
my $unconfirmed_fasta_file = $orient->unconfirmed_fasta_file;
my $unconfirmed_qual_file  = $orient->unconfirmed_qual_file;

my $confirmed_fasta_file_name = basename $confirmed_fasta_file;
my $confirmed_qual_file_name  = basename $confirmed_qual_file;
my $unconfirmed_fasta_file_name = basename $unconfirmed_fasta_file;
my $unconfirmed_qual_file_name  = basename $unconfirmed_qual_file;

is($confirmed_fasta_file_name,'assembled.confirmed.fasta', "confirmed_fasta_file return ok");
is($confirmed_qual_file_name,'assembled.confirmed.fasta.qual', "confirmed_qual_file return ok");
is($unconfirmed_fasta_file_name,'assembled.unconfirmed.fasta', "unconfirmed_fasta_file return ok");
is($unconfirmed_qual_file_name,'assembled.unconfirmed.fasta.qual', "unconfirmed_qual_file return ok");

ok($orient->execute, "Orient test fine");

is(compare($confirmed_fasta_file, "$dir/expected.confirmed.fasta"), 0, 'Expected and generated confirmed fasta matches');
is(compare($confirmed_qual_file, "$dir/expected.confirmed.fasta.qual"), 0, 'Expected and generated confirmed qual matches');
is(compare($unconfirmed_fasta_file, "$dir/expected.unconfirmed.fasta"), 0, 'Expected and generated unconfirmed fasta matches');
is(compare($unconfirmed_qual_file, "$dir/expected.unconfirmed.fasta.qual"), 0, 'Expected and generated unconfirmed qual matches');

unlink $confirmed_fasta_file;
unlink $confirmed_qual_file;
unlink $unconfirmed_fasta_file;
unlink $unconfirmed_qual_file;

#< Test failing conditions #>
# no primer files
$orient = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file => $fasta,
);
ok(!$orient, "Neither sense nor anti_sense file provided");

# non existing primer files
$orient = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file            => $fasta,
    anti_sense_fasta_file => $dir.'/no_way_this_exists.fasta',
);
ok(!$orient, "anti_sense file is invalid");

$orient = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file            => $fasta,
    sense_fasta_file => $dir.'/no_way_this_exists.fasta',
);
ok(!$orient, "anti_sense file is invalid");

exit;

#$HeadURL$
#$Id$
