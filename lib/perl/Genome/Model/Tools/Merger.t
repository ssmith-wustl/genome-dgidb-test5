#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use File::Compare;
use Test::More tests => 4;


BEGIN {use_ok('Genome::Model::Tools::Merger');}

my ($dir, $file_count) = ('/gsc/var/tmp/fasta/t/',5);
my @chunks;

for (my ($i, $file) = (0, undef); $i < $file_count; $i++)
{
    push(@chunks, $dir . "CHUNK_$i.static");
}

#create
my $merger = Genome::Model::Tools::Merger->create(
                merged_file     => $dir . 'merged.fna',
                force_overwrite => 1,
                file_chunks     => \@chunks);

isa_ok($merger, 'Genome::Model::Tools::Merger');
ok($merger->execute, "merging chunks");

#compare merged to static
my $static_file = $dir . 'merged.static';
cmp_ok(compare($static_file, $merger->merged_file), '==', 0, "$static_file matches " . $merger->merged_file);
