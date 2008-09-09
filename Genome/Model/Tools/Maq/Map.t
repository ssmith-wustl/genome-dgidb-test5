#!/usr/bin/env perl

package Genome::Model::Tools::Maq::Map::Test;
use Genome::Model::Tools::Maq::Map::Reader;
use Genome::Model::Tools::Maq::Map::Writer;
use Data::Dumper;
use Genome;                         # >above< ensures YOUR copy is used during development
use Test::More tests => 2;
use File::Temp;

class Genome::Model::Tools::Maq::Map::Test {
    is => 'Command',   
};

my $indata = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Map';
my ($outdata) = File::Temp::tempdir(CLEANUP => 1);

run_tests();

sub run_tests {
    my $command = __PACKAGE__->create();
    print "Testing Genome::Model::Tools::Maq::Map::Reader and Genome::Model::Tools::Maq::Map::Writer\n";
    ok($command->execute(),"Test executed");
    is(`cat $indata/2.map`, `cat $outdata/out.map`,"input file is same as output file");    

    1;
}

sub execute {
    my $self = shift;
    
    my $mi = Genome::Model::Tools::Maq::Map::Reader->new;
    my $mo = Genome::Model::Tools::Maq::Map::Writer->new;

    $mi->open("$indata/2.map");
    $mo->open("$outdata/out.map");

    my $header = $mi->read_header;
    #print Dumper($header);
    $mo->write_header($header);

    while(my $record = $mi->get_next)
    {
    #    print Dumper ($record);
        $mo->write_record($record);
    }
    $mi->close;
    $mo->close;
    
    return 1;
}

1;
