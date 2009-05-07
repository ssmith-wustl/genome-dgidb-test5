#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use File::Compare;
use Test::More tests => 9;


BEGIN {use_ok('Genome::Model::Tools::Fasta::Chunker');}

my ($dir, $chunk_size) = ('/gsc/var/tmp/fasta/t/',5);

#create
my $chunker = Genome::Model::Tools::Fasta::Chunker->create(
                fasta_file=> $dir . 'static.fna',
                tmp_dir => $dir,
                chunk_size=> $chunk_size,
);
isa_ok($chunker, 'Genome::Model::Tools::Fasta::Chunker');

#chunk file
ok($chunker->execute, 'chunking file');

#compare to static chunks 
my $file_chunks = $chunker->file_chunks;

for (my ($i,$static_chunk) = (0,undef); $i < $chunk_size; $i++)
{
    $static_chunk = $dir . 'CHUNK_' . $i . '.static';    
    cmp_ok(compare(@$file_chunks[$i],$static_chunk), '==', 0, "$static_chunk matches " . @$file_chunks[$i]);
}

#delete chunks
my $delete_files = Genome::Model::Tools::DeleteFiles->create(files => $file_chunks);
ok($delete_files->execute, "deleting file chunks");
