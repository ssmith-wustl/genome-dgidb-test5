#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run';

use above 'Workflow';
use Data::Dumper;

my $w = Workflow::Model->create_from_xml('data/pap_outer.xml');

my @errors = $w->validate;
die 'Too many problems: ' . join("\n", @errors) unless $w->is_valid();

my $out = $w->execute(
    'input' => {
        'fasta_file'       => 'data/B_coprocola.fasta',
        'chunk_size'       => 10,
        'biosql_namespace' => 'MGAP',
        'gram_stain'       => 'negative',
    }
);

$w->wait();

print Data::Dumper->new([$out])->Dump;

