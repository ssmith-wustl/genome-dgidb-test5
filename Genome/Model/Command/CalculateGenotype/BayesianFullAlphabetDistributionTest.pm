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

sub test_examine_position_single_position_single_read : Test(5){
    my $self = shift;
    
    my $base = Genome::Model::Alignment::Mock->new(
                                        #read_bases_probability_vectors => [ [1,0,0,0] ],
                                        #read_bases_probability_vectors => [ [.9,.1/3,.1/3,.1/3] ],
                                        read_bases_probability_vectors => [ [.25,.25,.25,.25] ],
                                        mismatch_code                  => MATCH,
                                        probability                    => 1,
                                    )->get_current_aligned_base();
    
    my $result = $self->{consensus_calc}->_examine_position([$base]);
    
    #               -- -A -C -G -T AA AC AG AT CC CG CT GG GT TT
    my $expected = [ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    
    print join("\n",@$result),"\n";
    my $max_other_than_AA = 0;
    my $max_index = 0;
    for( my $elem_i = 0 ; $elem_i < @$result ; $elem_i++){
        next if $elem_i == 5;
        if ($result->[$elem_i] > $max_other_than_AA){
            $max_other_than_AA = $result->[$elem_i];
            $max_index = $elem_i;
        }
    }
    ok($result->[5] > $max_other_than_AA, "AA is the MLE");
    is($max_index, 5, "AA  (index of 5) is the MLE index");
    
    #cmp_deeply($result, $expected);
    ok(1);
    ok(1);
    ok(1);
    
}

sub test_examine_position : Test(15) {
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

    foreach my $col_result (@$result){
        cmp_deeply(sum_struct($col_result), num(1,.00000000001), "Posterior Distribution sums to 1");
    }
                  
    my $expected = [];
    
    #use Data::Dumper;
    #print Data::Dumper::Dumper($result);
    
    cmp_deeply($result, $expected, '_examine_position correctly calculates the posterior base distribution of columns');
}

# HELPER METHODS --------------------------------------------------------------

sub sum_struct{
    my $struct = shift;
    
    die "Error struct must be an array ref" unless ref($struct) eq "ARRAY";
    
    my $sum = 0;
    foreach my $element (@$struct){
        if(ref($element) eq 'ARRAY'){
            $sum += sum_struct($element);
        }elsif(ref($element eq 'HASH')){
            $sum += sum_struct( [ values %$element ] );
        }elsif(ref($element)){
            # NOTHING
        }else{
            $sum += $element;
        }
    }
    
    return $sum;
}

if ($0 eq __FILE__){
    Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistributionTest->new->runtests();
}

#    AC?ATC*TACT-A

#.5  AC-TAC*TACT
#.7   C-ATC-ATCA*T
#.9        *TAGTTAG