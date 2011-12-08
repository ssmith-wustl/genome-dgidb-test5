#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use above "Genome";

my $class = 'Genome::DruggableGene::DrugGeneInteractionReport';
use_ok($class);
test_search_index_queue_priority();

sub test_search_index_queue_priority {
    my $iq_default_priority = Genome::Search::IndexQueue->default_priority();
    my $search_index_queue_priority = $class->search_index_queue_priority();
    is(($search_index_queue_priority - 1), $iq_default_priority, 'search_index_queue_priority is one greater than default_priority');
}

done_testing();
