#!/usr/bin/env perl

package Genome::Model::Tools::Maq::RemovePcrArtifacts::Test;

use above 'Genome';                         # >above< ensures YOUR copy is used during development
use Genome::Model::Tools::Maq::Map::Reader;
use Data::Dumper;
use Test::More tests => 2;
use File::Temp;

class Genome::Model::Tools::Maq::RemovePcrArtifacts::Test {
    is => 'Command',   
};

my $indata = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Map/2.map';
my ($outdata) = File::Temp::tempdir(CLEANUP => 1);




run_tests();

sub run_tests {
    my $command = __PACKAGE__->create();
    print "Testing Genome::Model::Tools::Maq::Map::Reader and Genome::Model::Tools::Maq::RemovePcrArtifacts\n";
    ok($command->execute(),"Test executed");
    
    
    my $mi_in = Genome::Model::Tools::Maq::Map::Reader->new;
    my $mi_del = Genome::Model::Tools::Maq::Map::Reader->new;
    my $mi_keep = Genome::Model::Tools::Maq::Map::Reader->new;
    
    my $mi = Genome::Model::Tools::Maq::Map::Reader->new;
    $mi->open("$outdata/del.2");
    my $header = $mi->read_header;
    $mi->close;
    print Dumper($header);
    
    is($header->{n_mapped_reads}, 0,"2nd pass duplicates file contains no duplicates.");    

    1;
}

sub execute {
    my $self = shift;
    
    Genome::Model::Tools::Maq::RemovePcrArtifacts->execute(input => $indata,
                                                           keep => $outdata.'/keep.1',
                                                           remove => $outdata.'/del.1',
                                                           identity_length => 26);
                                                           
    Genome::Model::Tools::Maq::RemovePcrArtifacts->execute(input => $outdata.'/keep.1',
                                                           keep => $outdata.'/keep.2',
                                                           remove => $outdata.'/del.2',
                                                           identity_length => 26);



    return 1;
}

1;
