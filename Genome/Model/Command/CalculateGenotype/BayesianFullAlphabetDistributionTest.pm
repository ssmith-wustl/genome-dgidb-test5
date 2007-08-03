#!/usr/bin/env perl

use strict;
use warnings;

use lib '/gsc/scripts/test/ur-dev';

package Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistributionTest;
use base 'Test::Class';

use Test::More;
use Test::Deep;

use Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistribution;
use Genome::Model::RefSeqAlignmentCollection;
use Genome::Model::Alignment::Mock;

use constant MATCH              => 0;
use constant MISMATCH           => 1;
use constant QUERY_INSERT       => 3;
use constant REFERENCE_INSERT   => 2;

my $tr = [qw/ -- -A -C -G -T AA AC AG AT CC CG CT GG GT TT/];

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
        [ [[0,0,0,0], QUERY_INSERT] ], #
        [ [[.2/3,.2/3,.2/3,.8], MATCH], [[.95,.05/3,.05/3,.05/3], MATCH], [[.1/3,.1/3,.1/3,.9], MATCH]], #
        [ [[.7,.3/3,.3/3,.3/3], MATCH], [[.2/3,.2/3,.2/3,.8], MATCH], [[.7,.3/3,.3/3,.3/3], MATCH]],     #
        [ [[.2/3,.8,.2/3,.2/3], MATCH], [[.33/3,.67,.33/3,.33/3], MATCH], [[.01/3,.01/3,.99,.01/3], MATCH]],     #
        [ [[.5/3,.5/3,.5/3,.5], MATCH], [[.4,.6/3,.6/3,.6/3], MATCH], [[.4/3,.4/3,.4/3,.6], MATCH]],     #
        [ [[.45/3,.45/3,.45/3,.55], MATCH] ],               #
        [ [[.1/3,.1/3,.1/3,.9], MATCH], [[.8,.2/3,.2/3,.2/3], MATCH] ],               #
        [ [[.3/3,.3/3,.7,.3/3], MATCH] ],                          #
    ];
    
    $self->{fake_alignments} = $fake_alignments;
}

sub test_calculate_diploid_genotype_priors : Test(1){
    my $self = shift;
    
    my $result = $self->{consensus_calc}->_calculate_diploid_genotype_priors();
    
    cmp_deeply(sum_struct($result), num(1,.000000001));
}

sub test_examine_position_single_position_heterozygote : Test(1){
    my $self = shift;
    
    my $base1 = Genome::Model::Alignment::Mock->new(
                                        read_bases_probability_vectors => [ [0,0,0,1] ],
                                        mismatch_code                  => MATCH,
                                        probability                    => 1,
                                    )->get_current_aligned_base();
    
    my $base2 = Genome::Model::Alignment::Mock->new(
                                        read_bases_probability_vectors => [ [1,0,0,0] ],
                                        mismatch_code                  => MATCH,
                                        probability                    => 1,
                                    )->get_current_aligned_base();
    
    my $result = $self->{consensus_calc}->_examine_position([$base1, $base2]);
    
    my $elem_i = 0;
    foreach my $elem (@$result){
        print "Post $tr->[$elem_i] is $result->[$elem_i]\n";
        $elem_i++;
    }
    
    my $expected = [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0];
    
    cmp_deeply($result, $expected);
}

#sub test_examine_position_single_position_single_read : Test(4){
#    my $self = shift;
#    
#    my $base = Genome::Model::Alignment::Mock->new(
#                                        read_bases_probability_vectors => [ [.9,.1/3,.1/3,.1/3] ],
#                                        mismatch_code                  => MATCH,
#                                        probability                    => 1,
#                                    )->get_current_aligned_base();
#    
#    my $result = $self->{consensus_calc}->_examine_position([$base]);
#    
#    # Test Set 1
#    {
#        cmp_deeply( sum_struct($result), num(1,.000000001), "Posterior distribution sums to 1");
#    }
#    
#
#    
#    # Test Set 2
#    {
#        my $max_other_than_AA = 0;
#        my $max_index = 0;
#        for( my $elem_i = 0 ; $elem_i < @$result ; $elem_i++){
#            next if $elem_i == 5;
#            if ($result->[$elem_i] > $max_other_than_AA){
#                $max_other_than_AA = $result->[$elem_i];
#            }
#        }
#        
#        ok($result->[5] > $max_other_than_AA, "AA is the MLE");
#    }
#    
#    # Test Set 3
#    {
#        my $max = 0;
#        my $max_index = 0;
#        for( my $elem_i = 0 ; $elem_i < @$result ; $elem_i++){
#            if ($result->[$elem_i] > $max){
#                $max = $result->[$elem_i];
#                $max_index = $elem_i;
#            }
#        }
#       
#        is($max_index, 5, "AA  (index of 5) is the MLE index");
#    }
#    
#    # Test Set 4
#    {
#        #               -- -A -C -G -T AA AC AG AT CC CG CT GG GT TT
#        my $expected = [qw/
#                                            0
#                         2.88005759994237e-10
#                         1.06668799997866e-11
#                         1.06668799997866e-11
#                         1.06668799997866e-11
#                         0.359999999884797
#                         0.186666666606932
#                         0.186666666606932
#                         0.186666666606932
#                         0.0133333333290666
#                         0.0133333333290666
#                         0.0133333333290666
#                         0.0133333333290666
#                         0.0133333333290666
#                         0.0133333333290666
#                       /];
#        
#        cmp_deeply($result, $expected);
#    }
#}
#
#sub test_examine_position_single_position_single_read_uniform : Test(2){
#    my $self = shift;
#    
#    my $base = Genome::Model::Alignment::Mock->new(
#                                        read_bases_probability_vectors => [ [.25,.25,.25,.25] ],
#                                        mismatch_code                  => MATCH,
#                                        probability                    => 1,
#                                    )->get_current_aligned_base();
#    
#    my $result = $self->{consensus_calc}->_examine_position([$base]);
#    
#    cmp_deeply( sum_struct($result), num(1,.000000001), "Posterior distribution sums to 1");
#    
#    my $expected = [
#                        0,
#                        2.5e-06,
#                        2.5e-06,
#                        2.5e-06,
#                        2.5e-06,
#                        0.0624993749999999,
#                        0.0624993749999999,
#                        0.0624993749999999,
#                        0.0624993749999999,
#                        0.0624993749999999,
#                        0.0624993749999999,
#                        0.0624993749999999,
#                        0.0624993749999999,
#                        0.0624993749999999,
#                        0.0624993749999999,
#                       ];
#        
#    cmp_deeply($result, $expected);
#}

sub test_examine_position_single_position_single_read_certainty : Test(1){
    my $self = shift;
    
    my $base = Genome::Model::Alignment::Mock->new(
                                        read_bases_probability_vectors => [ [0, 0, 1, 0] ],
                                        mismatch_code                  => MATCH,
                                        probability                    => 1,
                                    )->get_current_aligned_base();
    
    my $result = $self->{consensus_calc}->_examine_position([$base]);

    my $expected = [
                        0,
                        0,
                        0,
                        1e-05,
                        0,
                        0,
                        0,
                        0.2499975,
                        0,
                        0,
                        0.2499975,
                        0,
                        0.2499975,
                        0.2499975,
                        0
                       ];
        
        cmp_deeply($result, $expected);
}

sub test_examine_position_single_position_single_read_ambiguous_placement : Test(1){
    my $self = shift;
    
    my $base = Genome::Model::Alignment::Mock->new(
                                        read_bases_probability_vectors => [ [.1/3, .1/3, .1/3, .9] ],
                                        mismatch_code                  => MATCH,
                                        probability                    => .5,
                                    )->get_current_aligned_base();
    
    my $result = $self->{consensus_calc}->_examine_position([$base]);
    
    cmp_deeply( sum_struct($result), num(.5, .000000001), "Posterior distribution sums to .5");
}

#sub test_examine_position : Test(16) {
#    my $self = shift;
#    
#    my $result = [
#                    map {
#                      $self->{consensus_calc}->_examine_position(
#                          [
#                              map {
#                                  Genome::Model::Alignment::Mock->new(
#                                        read_bases_probability_vectors => [ $_->[0] ],
#                                        mismatch_code                  => $_->[1],
#                                        probability                    => 1,
#                                    )->get_current_aligned_base()
#                                  }
#                              @$_
#                           ]
#                          )
#                    } @{$self->{fake_alignments}}
#                  ];
#
#    foreach my $col_result (@$result){
#        cmp_deeply(sum_struct($col_result), num(1,.00000000001), "Posterior Distribution sums to 1");
#    }
#    
#    my $expected = [
#          [
#            0,
#            '3.16806335993661e-10',
#            '1.06668799997866e-12',
#            '1.06668799997866e-12',
#            '1.06668799997866e-12',
#            '0.395999999873277',
#            '0.198666666603092',
#            '0.198666666603092',
#            '0.198666666603092',
#            '0.00133333333290666',
#            '0.00133333333290666',
#            '0.00133333333290666',
#            '0.00133333333290666',
#            '0.00133333333290666',
#            '0.00133333333290666'
#          ],
#          [
#            0,
#            '5.20340813320324e-17',
#            '1.26442817636839e-14',
#            '5.20340813320324e-17',
#            '5.20340813320324e-17',
#            '0.00162601626016258',
#            '0.198373983739835',
#            '0.00162601626016258',
#            '0.00162601626016258',
#            '0.395121951219507',
#            '0.198373983739835',
#            '0.198373983739835',
#            '0.00162601626016258',
#            '0.00162601626016258',
#            '0.00162601626016258'
#          ],
#          [
#            '3.20009600191993e-14',
#            '0.249999999999992',
#            '0.249999999999992',
#            '0.249999999999992',
#            '0.249999999999992',
#            0,
#            0,
#            0,
#            0,
#            0,
#            0,
#            0,
#            0,
#            0,
#            0
#          ],
#          [
#            0,
#            '2.45113736317276e-15',
#            '5.44697191816169e-16',
#            '5.44697191816169e-16',
#            '9.25985226087487e-15',
#            '0.0765957446808501',
#            '0.0468085106382973',
#            '0.0468085106382973',
#            '0.182978723404253',
#            '0.0170212765957445',
#            '0.0170212765957445',
#            '0.1531914893617',
#            '0.0170212765957445',
#            '0.1531914893617',
#            '0.289361702127656'
#          ],
#          [
#            0,
#            '2.45113736317276e-15',
#            '5.44697191816169e-16',
#            '5.44697191816169e-16',
#            '9.25985226087487e-15',
#            '0.0765957446808501',
#            '0.0468085106382973',
#            '0.0468085106382973',
#            '0.182978723404253',
#            '0.0170212765957445',
#            '0.0170212765957445',
#            '0.1531914893617',
#            '0.0170212765957445',
#            '0.1531914893617',
#            '0.289361702127656'
#          ],
#          [
#            0,
#            '3.91449052222629e-17',
#            '1.26829492920132e-14',
#            '3.91449052222629e-17',
#            '3.91449052222629e-17',
#            '0.00122324159021405',
#            '0.198776758409783',
#            '0.00122324159021405',
#            '0.00122324159021405',
#            '0.396330275229353',
#            '0.198776758409783',
#            '0.198776758409783',
#            '0.00122324159021405',
#            '0.00122324159021405',
#            '0.00122324159021405'
#          ],
#          [
#            '8.00015999599978e-10',
#            '0.249999999799996',
#            '0.249999999799996',
#            '0.249999999799996',
#            '0.249999999799996',
#            0,
#            0,
#            0,
#            0,
#            0,
#            0,
#            0,
#            0,
#            0,
#            0
#          ],
#          [
#            0,
#            '1.37557741033077e-20',
#            '1.52841934481197e-21',
#            '1.52841934481197e-21',
#            '4.95207867719079e-19',
#            '0.0107462686567164',
#            '0.00597014925373134',
#            '0.00597014925373134',
#            '0.198805970149254',
#            '0.00119402985074627',
#            '0.00119402985074627',
#            '0.194029850746269',
#            '0.00119402985074627',
#            '0.194029850746269',
#            '0.386865671641791'
#          ],
#          [
#            0,
#            '3.98238151509341e-19',
#            '8.12730921447635e-21',
#            '8.12730921447635e-21',
#            '9.75277105737162e-20',
#            '0.311111111111111',
#            '0.158730158730159',
#            '0.158730158730159',
#            '0.193650793650794',
#            '0.00634920634920635',
#            '0.00634920634920635',
#            '0.0412698412698413',
#            '0.00634920634920635',
#            '0.0412698412698413',
#            '0.0761904761904762'
#          ],
#          [
#            0,
#            '1.376062859915e-21',
#            '1.00577685397424e-19',
#            '4.08690669394756e-19',
#            '1.376062859915e-21',
#            '0.00107500610798925',
#            '0.0398240899096018',
#            '0.160175910090398',
#            '0.00107500610798925',
#            '0.0785731737112143',
#            '0.198924993892011',
#            '0.0398240899096018',
#            '0.319276814072807',
#            '0.160175910090398',
#            '0.00107500610798925'
#          ],
#          [
#            0,
#            '5.85166263442298e-20',
#            '2.92583131721149e-20',
#            '2.92583131721149e-20',
#            '3.94987227823551e-19',
#            '0.0457142857142857',
#            '0.0342857142857143',
#            '0.0342857142857143',
#            '0.177142857142857',
#            '0.0228571428571429',
#            '0.0228571428571429',
#            '0.165714285714286',
#            '0.0228571428571429',
#            '0.165714285714286',
#            '0.308571428571429'
#          ],
#          [
#            0,
#            '4.80009599990396e-11',
#            '4.80009599990396e-11',
#            '4.80009599990396e-11',
#            '1.76003519996478e-10',
#            '0.0599999999807996',
#            '0.0599999999807996',
#            '0.0599999999807996',
#            '0.139999999955199',
#            '0.0599999999807996',
#            '0.0599999999807996',
#            '0.139999999955199',
#            '0.0599999999807996',
#            '0.139999999955199',
#            '0.219999999929599'
#          ],
#          [
#            0,
#            '3.74645385590633e-15',
#            '3.12204487992194e-16',
#            '3.12204487992194e-16',
#            '8.42952117578924e-15',
#            '0.117073170731706',
#            '0.0634146341463406',
#            '0.0634146341463406',
#            '0.190243902439022',
#            '0.00975609756097548',
#            '0.00975609756097548',
#            '0.136585365853657',
#            '0.00975609756097548',
#            '0.136585365853657',
#            '0.263414634146338'
#          ],
#          [
#            0,
#            '3.20006399993597e-11',
#            '3.20006399993597e-11',
#            '2.24004479995518e-10',
#            '3.20006399993597e-11',
#            '0.0399999999871997',
#            '0.0399999999871997',
#            '0.159999999948799',
#            '0.0399999999871997',
#            '0.0399999999871997',
#            '0.159999999948799',
#            '0.0399999999871997',
#            '0.279999999910398',
#            '0.159999999948799',
#            '0.0399999999871997'
#          ]
#        ];
#       
#    cmp_deeply($result, $expected, '_examine_position correctly calculates the posterior base distribution of columns');
#
#    my $MLE_indexes = [];
#    foreach my $column ( @$result ){
#        
#        my $max = 0;
#        my $max_index = 0;
#        my $index = 0;
#        foreach my $elem ( @$column ){
#            if($elem > $max){
#                $max = $elem;
#                $max_index = $index
#            }elsif($elem == $max){
#                #print "Warning! The Posterior is flat over several models ($elem:$index, $max:$max_index)\n";
#            }
#            $index++;
#        }
#        push @$MLE_indexes, $max_index;
#    }
#
#                #  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14
#    my $tr = [qw/ -- -A -C -G -T AA AC AG AT CC CG CT GG GT TT/];
#    
#                    #    AC?ATC*TACT-A
#                    #.5  AC-TAC*TACT
#                    #.7   C-ATC-ATCA*T
#                    #.9        *TAGTTAG
#
#    my $expected_mle_genotype_indexes = [5, 9, 1, 14, 14, 9, 1,8 ,14, 8, 10, 8, 14, 8, 12];
#
#    #my $i = 0;
#    #foreach (@{$result->[7]}){
#    #    print $tr->[$i], " ", $_, "\n";
#    #    $i++;
#    #}
#
#    $expected_mle_genotype_indexes = [map {$tr->[$_]} @$expected_mle_genotype_indexes];
#    $MLE_indexes = [map {$tr->[$_]} @$MLE_indexes];
#
#    cmp_deeply($MLE_indexes, $expected_mle_genotype_indexes);
#}
#
## HELPER METHODS --------------------------------------------------------------
#
sub sum_struct{
    my $struct = shift;
    
    die "Error struct must be an array ref" unless ref($struct) eq "ARRAY";
    
    my $sum = 0;
    foreach my $element (@$struct){
        
        next unless $element; # ... i cant figure out why this needs to be here, but it does
        
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
#
if ($0 eq __FILE__){
    Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistributionTest->new->runtests();
}
#
##    AC?ATC*TACT-A
#
##.5  AC-TAC*TACT
##.7   C-ATC-ATCA*T
##.9        *TAGTTAG

1;