#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";                         # >above< ensures YOUR copy is used during development

use Genome::Model::Tools::Maq::Map::Writer;
use Test::More tests => 8;
use File::Temp;
use Storable;

my $indata = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Map';
my $hash = retrieve "$indata/test.store";
my ($outdata) = File::Temp::tempdir(CLEANUP => 1);

my $mo;
ok($mo = Genome::Model::Tools::Maq::Map::Writer->new(file_name => "$outdata/out.map"), 'create writer from object with filename');
ok($mo = Genome::Model::Tools::Maq::Map::Writer->new,'create writer from class');
ok(bless({},'Genome::Model::Tools::Maq::Map::Writer')->new,'create writer from object');
ok(do {
    my $mo;
    eval {
        $mo = Genome::Model::Tools::Maq::Map::Writer::new;
    };
    $@ ? 1 : 0;
},'writer creation failed gracefully');


ok($mo->open("$outdata/out.map"),'open out.map');

ok(!$mo->write_header($hash->{header}),'write header');

while(my $record = shift @{$hash->{records}})
{
    $mo->write_record($record);
}

ok(!$mo->close,'close out.map');

is(`cat $indata/2.map`, `cat $outdata/out.map`,"input file is same as output file");     




