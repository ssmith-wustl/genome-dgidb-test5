#!/usr/bin/env perl

use strict;
use warnings;

use Genome::Model::RefSeqAlignmentCollection;

use lib '/gsc/scripts/test/ur-dev';

package Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistributionTest;
use base 'Test::Class';

use Test::More;
use Test::Deep;

use Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistribution;
use Genome::Model::Alignment::Mock;

use constant MATCH => 0;
use constant MISMATCH => 1;
use constant QUERY_INSERT => 3;
use constant REFERENCE_INSERT => 2;

sub setup : Test(setup){
    my $self = shift;
    
    my $consensus_results = [];
    $self->{consensus_results} = $consensus_results;
    
    my $consensus_calc = Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistribution->create(
            length      => 1,
            result      => $consensus_results,
    );
    $self->{consensus_calc} = $consensus_calc;
    
    my $fake_alignments = [
        [ [[.99,.01/3,.01/3,.01/3], MATCH] ],                               #
        [ [[.25/3,.75,.25/3,.25/3], MATCH], [[.1/3,.9,.1/3,.1/3], MATCH] ], #
        [ [[0,0,0,0], QUERY_INSERT], [[0,0,0,0], QUERY_INSERT] ],           #
        [ [[.15/3,.15/3,.15/3,.85], MATCH], [[.6,.4/3,.4/3,.4/3], MATCH] ], #
        [ [[.6,.4/3,.4/3,.4/3], MATCH], [[.15/3,.15/3,.15/3,.85], MATCH] ], #
        [ [[.2/3,.8,.2/3,.2/3], MATCH], [[.1/3,.9,.1/3,.1/3], MATCH] ],     #
        [ [[0,0,0,0], QUERY_INSERT] ],                                      #
        [ [[.2/3,.2/3,.2/3,.8], MATCH], [[.75,.25/3,.25/3,.25/3], MATCH], [[.1/3,.1/3,.1/3,.9], MATCH]], #
        [ [[.7,.3/3,.3/3,.3/3], MATCH], [[.2/3,.2/3,.2/3,.8], MATCH], [[.7,.3/3,.3/3,.3/3], MATCH]],     #
        [ [[.2/3,.8,.2/3,.2/3], MATCH], [[.33/3,.67,.33/3,.33/3], MATCH], [[.01/3,.01/3,.99,.01/3], MATCH]],     #
        [ [[.5/3,.5/3,.5/3,.5], MATCH], [[.4,.6/3,.6/3,.6/3], MATCH], [[.4/3,.4/3,.4/3,.6], MATCH]],     #
        [ [[.45/3,.45/3,.45/3,.55], MATCH] ],               #
        [ [[.1/3,.1/3,.1/3,.9], MATCH], [[.8,.2/3,.2/3,.2/3], MATCH] ],               #
        [ [[.3/3,.3/3,.7,.3/3], MATCH] ],                          #
    ];
    
    $self->{fake_alignments} = $fake_alignments;
}

sub test_examine_position : Test(1) {
    my $self = shift;
    
    my $result = [
                    map {
                      $self->{consensus_calc}->_examine_position(
                          [
                              map {
                                  Genome::Model::Alignment::Mock->new(
                                        read_bases_probability_vectors => [ $_->[0] ],
                                        mismatch_code                  => $_->[1],
                                        probability                    => 1,
                                    )->get_current_aligned_base()
                                  }
                              @$_
                           ]
                          )
                    } @{$self->{fake_alignments}}
                  ];
                  
    my $expected = [];
    
    use Data::Dumper;
    print Data::Dumper::Dumper($result);
    
    cmp_deeply($result, $expected, '_examine_position correctly calculates the posterior base distribution of columns');
}

if ($0 eq __FILE__){
    Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistributionTest->new->runtests();
}

#    AC?ATC*TACT-A

#.5  AC-TAC*TACT
#.7   C-ATC-ATCA*T
#.9        *TAGTTAG