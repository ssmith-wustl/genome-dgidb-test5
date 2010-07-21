#!/gsc/bin/perl

use strict;
use warnings;
use above "Genome";

use Cwd;
use Test::More tests => 4;

my $chromosome = "1";	
my $start = 1;
my $stop = 10000;
my $organism = "human";
my $version = "54_36p_v2";
my $output = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptRegions/TranscriptRegions.t.output.txt";
my $expected_output = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-TranscriptRegions/TranscriptRegions.t.expected.output.txt.new";

ok(-e $expected_output);

my $regions = Genome::Model::Tools::Annotate::TranscriptRegions->create(chromosome=>$chromosome,start=>$start,stop=>$stop,organism=>$organism,version=>$version,output=>$output);
ok($regions);

ok($regions->execute());

my $diff = `sdiff -s $output $expected_output`;
ok($diff eq '', "output as expected") or diag($diff);



###foreach my $ordered_transcript_number (sort {$a<=>$b} keys %{$regions->{transcript}}) {
###    my $hugo_gene_name = $regions->{transcript}->{$ordered_transcript_number}->{hugo_gene_name};
###    my $transcript = $regions->{transcript}->{$ordered_transcript_number}->{transcript_name};
###    print qq($hugo_gene_name $transcript\n);
###    
###    foreach my $n (sort {$a<=>$b} keys %{$regions->{transcript}->{$ordered_transcript_number}->{structure}}) {
###	my ($structure_region,$tr_start,$tr_stop) = split(/\:/,$regions->{transcript}->{$ordered_transcript_number}->{structure}->{$n});
###	print qq(\t$n\t$structure_region\t$tr_start\t$tr_stop\n);
###	
###    }
###}
