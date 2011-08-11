#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Storable;
use Test::More;

my $ace_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-AceReader/test.ace';
my $stor_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Consed-AceReader/test.stor';
my $ace = Genome::Model::Tools::Consed::AceReader->create(
    file => $ace_file,
);
ok($ace, 'create ace reader');
my $expected = retrieve($stor_file);
ok($expected, 'got expected objects') or die;
my @got;
while ( my $obj = $ace->next ) {
    push @got, $obj;
}
is_deeply(\@got, $expected, 'objects match');

done_testing();
exit;

