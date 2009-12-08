#!/gsc/bin/perl

use strict;
use warnings;
use above "Genome"; 
use Test::More tests => 1;
             	
my $event_id = 88961295; # 88986518;	
my $event = Genome::Model::Event->get($event_id);
ok($event, "got an event");

#this is time consuming. comment out for autorun.
#my @metrics = $event->generate_metric();
#is(scalar(@metrics), 18, "got metrics");
#
#my %metrics;
#for my $metric (@metrics) {
#    $metrics{$metric->name} = $metric;
#}
#
#{
#    skip "won't test fwd/rev counts using fragment data", 2 unless $event->instrument_data->is_paired_end;
#
#    is($metrics{'fwd_aligned_read_count'} + $metrics{'rev_aligned_read_count'}, $metrics{'aligned_read_count'}, 'fwd/rev aligned read counts sum to overall aligned');
#    is($metrics{'fwd_unaligned_read_count'} + $metrics{'rev_unaligned_read_count'}, $metrics{'unaligned_read_count'}, 'fwd/rev unaligned read counts sum to overall unaligned');
#    is($metrics{'fwd_reads_passed_quality_filter_count'} + $metrics{'rev_reads_passed_quality_filter_count'}, $metrics{'total_reads_passed_quality_filter_count'}, 'fwd/rev read passed filter counts sum to total reads passed filter');
#}
#
#is($metrics{'unaligned_read_count'} + $metrics{'aligned_read_count'}, $metrics{'total_reads_passed_quality_filter_count'}, 'unaligned and aligned read counts sum to total reads passed filter');
