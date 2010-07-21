#!/gsc/bin/perl

use strict;
use warnings;
use above 'Genome';
use Genome;

use Genome::Model::Tools::Assembly::MergeScaffolds;

use Test::More tests => 1;

my $path = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly-SplitScaffold';

my $ace_file = 'merge.ace';
my $out_file_name = 'out.ace';
my $left_scaffold = 'Contig60.1';
my $right_scaffold = 'Contig120.1';
chdir($path);
system "/bin/rm -f *.db";
ok(Genome::Model::Tools::Assembly::MergeScaffolds->execute(ace_file => $ace_file, left_scaffold => $left_scaffold, right_scaffold => $right_scaffold, out_file_name => $out_file_name), "MergeScaffolds executed successfully");

