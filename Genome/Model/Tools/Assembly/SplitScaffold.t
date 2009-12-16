#!/gsc/bin/perl

use strict;
use warnings;
use above 'Genome';
use Genome;

use Genome::Model::Tools::Assembly::SplitScaffold;

use Test::More tests => 1;

my $path = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly-SplitScaffold';

my $ace_file = 'merge.ace';
my $out_file_name = 'split_out.ace';
my $split_contig = 'Contig60.6';

chdir($path);
system "/bin/rm -f *.db";
ok(Genome::Model::Tools::Assembly::SplitScaffold->execute(ace_file => $ace_file, split_contig  => $split_contig, out_file_name => $out_file_name), "SplitScaffold executed successfully");

