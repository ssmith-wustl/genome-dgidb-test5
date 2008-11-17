#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 14;
use File::Compare;
use File::Temp;
use File::Basename;
use Bio::SeqIO;

BEGIN {
        use_ok ('Genome::Model::Tools::Fasta::Orient');
}

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fasta/Orient';
my $fasta    = $dir.'/test.fasta';
my $qual     = $dir.'/test.fasta.qual';
my $s_fasta  = $dir.'/sense.fasta';
my $as_fasta = $dir.'/anti_sense.fasta';

my $orient1 = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file       => $fasta,
    sense_fasta_file => $s_fasta,
);

my $orient_fasta_file = $orient1->oriented_fasta_file;
my $orient_qual_file  = $orient1->oriented_qual_file;

my $orient_fasta_file_name = basename $orient_fasta_file;
my $orient_qual_file_name  = basename $orient_qual_file;

is($orient_fasta_file_name,'test.oriented.fasta', "oriented_fasta_file return ok");
is($orient_qual_file_name,'test.oriented.fasta.qual', "oriented_qual_file return ok");

ok($orient1->execute, "Orient1 test fine");
is(compare("$dir/test.oriented.fasta", $fasta),0,'orient file is the same as original');

unlink $orient_fasta_file;
unlink $orient_qual_file;

my $orient2 = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file            => $fasta,
    anti_sense_fasta_file => $as_fasta,
);

ok($orient2->execute, "Orient2 test fine");
is(compare("$dir/test.oriented.fasta", $fasta),0,'orient file is the same as original');

unlink $orient_fasta_file;
unlink $orient_qual_file;

my $no_fasta = "$dir/no.fasta";

my $orient3 = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file            => $no_fasta,
    anti_sense_fasta_file => $as_fasta,
);

ok(!$orient3->execute, "No Fasta file provided");

my $non_sense = $dir.'/non_sense';
my $orient4 = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file            => $fasta,
    anti_sense_fasta_file => $non_sense,
);

ok(!$orient4, "anti_sense file is invalid");


my $orient5 = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file => $fasta,
);

ok(!$orient5, "Neither sense nor anti_sense file provided");

my $fasta2 = $dir.'/test2.fasta';
my $s_fasta2 = $dir.'/sense2.fasta';
my $as_fasta2 = $dir.'/anti_sense2.fasta';

my $orient6 = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file            => $fasta2,
    anti_sense_fasta_file => $as_fasta2,
    sense_fasta_file      => $s_fasta2,
);

my $orient2_fasta = $orient6->oriented_fasta_file;
ok($orient6->execute, "Multiple Fasta vs sense and anti_sense work");

unlink $orient2_fasta;

my $io = Bio::SeqIO->new(-format=>'fasta', -file => $fasta);
my $ori_seq = $io->next_seq->seq;

my $io_qual = Bio::SeqIO->new(-format=>'qual', -file => $qual);
my $ori_qual = $io_qual->next_seq->qual;

my $orient7 = Genome::Model::Tools::Fasta::Orient->create(
    fasta_file            => $fasta,
    anti_sense_fasta_file => $s_fasta,
);
my $orient7_fasta = $orient7->oriented_fasta_file;
my $orient7_qual  = $orient7->oriented_qual_file;

ok($orient7->execute, "Giving anti_sense_fasta_file option with sensefasta works");

my $io2= Bio::SeqIO->new(-format=>'fasta', -file => $orient7_fasta);
my $as = $io2->next_seq->revcom;
cmp_ok($ori_seq, 'eq', $as->seq, 'Giving anti_sense sense seq produces Reverse_complementing sequence');

my $io2_qual = Bio::SeqIO->new(-format=>'qual', -file => $orient7_qual);
my $as_qual = $io2_qual->next_seq->revcom;
is_deeply($ori_qual, $as_qual->qual, 'Giving anti_sense sense qual produces Reverse_complementing qual');

unlink $orient7_fasta;
unlink $orient7_qual;

exit;
