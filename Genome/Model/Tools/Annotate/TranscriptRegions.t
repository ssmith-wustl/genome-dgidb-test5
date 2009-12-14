#!/gsc/bin/perl

use strict;
use warnings;
use above "Genome";

use Test::More tests => 4;

my $chromosome = "1";	
my $start = 1;
my $stop = 10000;
my $organism = "human";
my $version = "54_36p";
my $output = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptRegions/TranscriptRegions.t.output.txt";
my $expected_output = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptRegions/TranscriptRegions.t.expected.output.txt";

ok(-e $expected_output);

my $regions = Genome::Model::Tools::Annotate::TranscriptRegions->create(chromosome=>$chromosome,start=>$start,stop=>$stop,organism=>$organism,version=>$version,output=>$output);
ok($regions);

ok($regions->execute());

my $diff = `diff $output $expected_output`;
ok($diff eq '', "output as expected");



#exit 1;

###foreach my $transcript (sort keys %{$regions->{transcript}}) {
###    my $hugo_gene_name = $regions->{transcript}->{$transcript}->{hugo_gene_name};
###    print qq($hugo_gene_name $transcript\n);
###    
###    foreach my $n (sort {$a<=>$b} keys %{$regions->{transcript}->{$transcript}->{structure}}) {
###	my ($structure_region,$tr_start,$tr_stop) = split(/\:/,$regions->{transcript}->{$transcript}->{structure}->{$n});
###	print qq(\t$n\t$structure_region\t$tr_start\t$tr_stop\n);
###	
###    }
###}
