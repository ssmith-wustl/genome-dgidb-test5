#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run';

use above 'Workflow';
use Data::Dumper;

my $w = Workflow::Model->create_from_xml('data/repeatmasker_outer.xml');

print join("\n", $w->validate) . "\n";

my $out = $w->execute(
    'input' => {
        'fasta_file' => 'data/C_elegans.ws184.fasta.bz2',
    }
);

$w->wait;

print Data::Dumper->new([$out])->Dump;

