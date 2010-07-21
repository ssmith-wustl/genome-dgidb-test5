#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run';

use above 'Workflow';
use Data::Dumper;

my $w = Workflow::Model->create_from_xml($ARGV[0] || 'data/pap_outer_keggless.xml');

my @errors = $w->validate;
die 'Too many problems: ' . join("\n", @errors) unless $w->is_valid();

my $out = $w->execute(
    'input' => {
        'fasta file'       => 'data/B_coprocola.chunk.fasta',
        'chunk size'       => 10,
        'biosql namespace' => 'MGAP',
        'gram stain'       => 'negative',
    }
);

$w->wait();

print Data::Dumper->new([$out])->Dump;

