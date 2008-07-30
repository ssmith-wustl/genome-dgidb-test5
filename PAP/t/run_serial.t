#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run';

use above 'Workflow';
use Data::Dumper;

my $w = Workflow::Model->create_from_xml('data/pap.xml');

print join("\n", $w->validate) . "\n";

my $out = $w->execute(
    'input' => {
        'fasta_file'       => 'data/B_coprocola.fasta',
        'chunk_size'       => 10,
        'biosql_namespace' => 'MGAP',
    }
);

$w->wait;

print Data::Dumper->new([$out])->Dump;

