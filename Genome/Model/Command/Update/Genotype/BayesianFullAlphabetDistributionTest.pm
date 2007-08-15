#!/usr/bin/env perl

use strict;
use warnings;

package Genome::Model::Command::Update::Genotype::BayesianFullAlphabetDistributionTest;
use base 'Test::Class';

use Test::More;
use Test::Deep;

use Genome::Model::Command::Update::Genotype::BayesianFullAlphabetDistribution;
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
    
    my $consensus_calc = Genome::Model::Command::Update::Genotype::BayesianFullAlphabetDistribution->create(
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
    
    my $result = Genome::Model::Command::Genotype::BayesianFullAlphabetDistribution::_calculate_diploid_genotype_priors();
    
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
    
    my $result = Genome::Model::Command::Genotype::BayesianFullAlphabetDistribution::_examine_position([$base1, $base2]);
    
    my $expected = [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0];
    
    cmp_deeply($result, $expected);
}

sub test_examine_position_single_position_single_read : Test(3){
    my $self = shift;
    
    my $base = Genome::Model::Alignment::Mock->new(
                                        read_bases_probability_vectors => [ [.9,.1/3,.1/3,.1/3] ],
                                        mismatch_code                  => MATCH,
                                        probability                    => 1,
                                    )->get_current_aligned_base();
    
    my $result = Genome::Model::Command::Genotype::BayesianFullAlphabetDistribution::_examine_position([$base]);
    
    # Test Set 1
    {
        cmp_deeply( sum_struct($result), num(1,.000000001), "Posterior distribution sums to 1");
    }
    
    # Test Set 3
    {
        my $max = 0;
        my $max_index = 0;
        for( my $elem_i = 0 ; $elem_i < @$result ; $elem_i++){
            if ($result->[$elem_i] > $max){
                $max = $result->[$elem_i];
                $max_index = $elem_i;
            }
        }
       
        is($max_index, 5, "AA  (index of 5) is the first MLE index");
    }
    
    # Test Set 4
    {
        #               -- -A -C -G -T AA AC AG AT CC CG CT GG GT TT
        my $expected = [qw/
                            0
                            9e-06
                            3.33333333333333e-07
                            3.33333333333333e-07
                            3.33333333333333e-07
                            0.22499775
                            0.233331
                            0.233331
                            0.233331
                            0.00833325
                            0.0166665
                            0.0166665
                            0.00833325
                            0.0166665
                            0.00833325
                       /];
        
        cmp_deeply($result, $expected);
    }
}

sub test_examine_position_single_position_single_read_gap_only : Test(2){
    my $self = shift;
    
    my $base = Genome::Model::Alignment::Mock->new(
                                        read_bases_probability_vectors => [ [0,0,0,0] ],
                                        mismatch_code                  => QUERY_INSERT,
                                        probability                    => .9999,
                                    )->get_current_aligned_base();
    
    my $result = Genome::Model::Command::Genotype::BayesianFullAlphabetDistribution::_examine_position([$base]);
    
    cmp_deeply( sum_struct($result), num(1,.000000001), "Posterior distribution sums to 1");
    
    my $expected = [qw/
                        2.85697958667645e-06
                        0.0714255611771178
                        0.0714255611771178
                        0.0714255611771178
                        0.0714255611771178
                        0.0446434311444964
                        0.0892868622889927
                        0.0892868622889927
                        0.0892868622889927
                        0.0446434311444964
                        0.0892868622889927
                        0.0892868622889927
                        0.0446434311444964
                        0.0892868622889927
                        0.0446434311444964
                       /];
        
    cmp_deeply($result, $expected);
}

sub test_examine_position_single_position_single_read_uniform : Test(2){
    my $self = shift;
    
    my $base = Genome::Model::Alignment::Mock->new(
                                        read_bases_probability_vectors => [ [.25,.25,.25,.25] ],
                                        mismatch_code                  => MATCH,
                                        probability                    => 1,
                                    )->get_current_aligned_base();
    
    my $result = Genome::Model::Command::Genotype::BayesianFullAlphabetDistribution::_examine_position([$base]);
    
    cmp_deeply( sum_struct($result), num(1,.000000001), "Posterior distribution sums to 1");
    
    my $expected = [qw/
                        0
                        2.5e-06
                        2.5e-06
                        2.5e-06
                        2.5e-06
                        0.0624993749999999
                        0.12499875
                        0.12499875
                        0.12499875
                        0.0624993749999999
                        0.12499875
                        0.12499875
                        0.0624993749999999
                        0.12499875
                        0.0624993749999999
                       /];
    
    cmp_deeply($result, $expected);
}

sub test_examine_position_single_position_single_read_certainty : Test(1){
    my $self = shift;
    
    my $base = Genome::Model::Alignment::Mock->new(
                                        read_bases_probability_vectors => [ [0, 0, 1, 0] ],
                                        mismatch_code                  => MATCH,
                                        probability                    => 1,
                                    )->get_current_aligned_base();
    
    my $result = Genome::Model::Command::Genotype::BayesianFullAlphabetDistribution::_examine_position([$base]);

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

sub test_examine_position_single_position_single_read_ambiguous_placement : Test(2){
    my $self = shift;
    
    my $base = Genome::Model::Alignment::Mock->new(
                                        read_bases_probability_vectors => [ [.1/3, .1/3, .1/3, .9] ],
                                        mismatch_code                  => MATCH,
                                        probability                    => .2,
                                    )->get_current_aligned_base();
    
    my $result = Genome::Model::Command::Genotype::BayesianFullAlphabetDistribution::_examine_position([$base]);
    
    cmp_deeply( sum_struct($result), num(1, .000000001), "Posterior distribution sums to 1");
    
    my $expected = [qw/
                        3.20005759975677e-15
                        2.0667431999509e-06
                        2.0667431999509e-06
                        2.0667431999509e-06
                        3.80009039950715e-06
                        0.0516660633169732
                        0.103332126633946
                        0.103332126633946
                        0.146665373286053
                        0.0516660633169732
                        0.103332126633946
                        0.146665373286053
                        0.0516660633169732
                        0.146665373286053
                        0.0949993099690796
                    /];
        
    cmp_deeply( $result, $expected );
}

sub test_examine_position : Test(16) {
    my $self = shift;
    
    my $result = [
                    map {
                      Genome::Model::Command::Genotype::BayesianFullAlphabetDistribution::_examine_position(
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

    
    #foreach my $col (@$result){
    #    my $elem_i = 0;
    #    print "[\n";
    #    foreach my $elem (@$col){
    #        print "$col->[$elem_i],\n";
    #        $elem_i++;
    #    }
    #    print "],\n";
    #}

    my $expected = [
                        [
                        0,
                        9.9e-06,
                        3.33333333333333e-08,
                        3.33333333333333e-08,
                        3.33333333333333e-08,
                        0.247497525,
                        0.24833085,
                        0.24833085,
                        0.24833085,
                        0.000833325,
                        0.00166665,
                        0.00166665,
                        0.000833325,
                        0.00166665,
                        0.000833325,
                        ],
                        [
                        0,
                        2.97619844815061e-08,
                        7.23216222900597e-06,
                        2.97619844815061e-08,
                        2.97619844815061e-08,
                        0.00148808434308306,
                        0.208331808031629,
                        0.00297616868616612,
                        0.00297616868616612,
                        0.361604495369184,
                        0.208331808031629,
                        0.208331808031629,
                        0.00148808434308306,
                        0.00297616868616612,
                        0.00148808434308306,
                        ],
                        [
                        1.9999800002e-05,
                        0.249995000049999,
                        0.249995000049999,
                        0.249995000049999,
                        0.249995000049999,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        ],
                        [
                        0,
                        7.37709453131884e-07,
                        1.63935434029308e-07,
                        1.63935434029308e-07,
                        2.78690237849823e-06,
                        0.0368851038018676,
                        0.045081793535616,
                        0.045081793535616,
                        0.405736141820544,
                        0.00819668973374836,
                        0.0163933794674967,
                        0.147540415207471,
                        0.00819668973374836,
                        0.147540415207471,
                        0.139343725473722,
                        ],
                        [
                        0,
                        7.37709453131884e-07,
                        1.63935434029308e-07,
                        1.63935434029308e-07,
                        2.78690237849823e-06,
                        0.0368851038018676,
                        0.045081793535616,
                        0.045081793535616,
                        0.405736141820544,
                        0.00819668973374836,
                        0.0163933794674967,
                        0.147540415207471,
                        0.00819668973374836,
                        0.147540415207471,
                        0.139343725473722,
                        ],
                        [
                        0,
                        2.27531867971221e-08,
                        7.37203252226755e-06,
                        2.27531867971221e-08,
                        2.27531867971221e-08,
                        0.0011376479632627,
                        0.207051929313812,
                        0.00227529592652541,
                        0.00227529592652541,
                        0.368597940097116,
                        0.207051929313812,
                        0.207051929313812,
                        0.0011376479632627,
                        0.00227529592652541,
                        0.0011376479632627,
                        ],
                        [
                        1e-05,
                        0.2499975,
                        0.2499975,
                        0.2499975,
                        0.2499975,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        ],
                        [
                        0,
                        9.27894098437257e-08,
                        1.62788438322326e-09,
                        1.62788438322326e-09,
                        5.27434540164336e-07,
                        0.00927884819496272,
                        0.00944163500540067,
                        0.00944163500540067,
                        0.859188785491461,
                        0.000162786810437943,
                        0.000325573620875885,
                        0.0296271994997055,
                        0.000162786810437943,
                        0.0296271994997055,
                        0.0527429265818934,
                        ],
                        [
                        0,
                        1.3498734149318e-06,
                        2.75484370394246e-08,
                        2.75484370394246e-08,
                        3.30581244473095e-07,
                        0.134985991619765,
                        0.0881541169761734,
                        0.0881541169761734,
                        0.573001760345127,
                        0.00275481615550542,
                        0.00550963231101083,
                        0.0358126100215704,
                        0.00275481615550542,
                        0.0358126100215704,
                        0.033057793866065,
                        ],
                        [
                        0,
                        1.26107498044991e-09,
                        9.21731167528845e-08,
                        3.74539269193624e-07,
                        1.26107498044991e-09,
                        0.000126106236970011,
                        0.00581235110398141,
                        0.0375796586170632,
                        0.000252212473940022,
                        0.0092172195021717,
                        0.86604031449323,
                        0.00581235110398141,
                        0.0374535523800932,
                        0.0375796586170632,
                        0.000126106236970011,
                        ],
                        [
                        0,
                        3.12502270524309e-07,
                        1.56251135262155e-07,
                        1.56251135262155e-07,
                        2.10939032603909e-06,
                        0.0312499145501604,
                        0.0468748718252406,
                        0.0468748718252406,
                        0.257811795038823,
                        0.0156249572750802,
                        0.0312499145501604,
                        0.171874530025882,
                        0.0156249572750802,
                        0.171874530025882,
                        0.210936923213583,
                        ],
                        [
                        0,
                        1.5e-06,
                        1.5e-06,
                        1.5e-06,
                        5.5e-06,
                        0.037499625,
                        0.07499925,
                        0.07499925,
                        0.17499825,
                        0.037499625,
                        0.07499925,
                        0.17499825,
                        0.037499625,
                        0.17499825,
                        0.137498625,
                        ],
                        [
                        0,
                        7.81764687200476e-07,
                        6.51470572667064e-08,
                        6.51470572667064e-08,
                        1.75897054620107e-06,
                        0.0390878434776802,
                        0.0423451637674869,
                        0.0423451637674869,
                        0.592832292744817,
                        0.00325732028980668,
                        0.00651464057961337,
                        0.0912049681145872,
                        0.00325732028980668,
                        0.0912049681145872,
                        0.0879476478247805,
                        ],
                        [
                        0,
                        1e-06,
                        1e-06,
                        7e-06,
                        1e-06,
                        0.02499975,
                        0.0499995,
                        0.199998,
                        0.0499995,
                        0.02499975,
                        0.199998,
                        0.0499995,
                        0.17499825,
                        0.199998,
                        0.02499975,
                        ],
        ];
       
    cmp_deeply($result, $expected, '_examine_position correctly calculates the posterior base distribution of columns');

    my $MLE_indexes = [];
    foreach my $column ( @$result ){
        
        my $max = 0;
        my $max_index = 0;
        my $index = 0;
        foreach my $elem ( @$column ){
            if($elem > $max){
                $max = $elem;
                $max_index = $index
            }elsif($elem == $max){
                #print "Warning! The Posterior is flat over several models ($elem:$index, $max:$max_index)\n";
            }
            $index++;
        }
        push @$MLE_indexes, $max_index;
    }

                #  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14
    my $tr = [qw/ -- -A -C -G -T AA AC AG AT CC CG CT GG GT TT/];
    
                    #    AC?ATC*TACT-A
                    #.5  AC-TAC*TACT
                    #.7   C-ATC-ATCA*T
                    #.9        *TAGTTAG

    my $expected_mle_genotype_indexes = [5, 9, 0, 14, 14, 9, 0,14 ,5, 12, 14, 14, 14, 12];

    $expected_mle_genotype_indexes = [map {$tr->[$_]} @$expected_mle_genotype_indexes];
    $MLE_indexes = [map {$tr->[$_]} @$MLE_indexes];

    cmp_deeply($MLE_indexes, $expected_mle_genotype_indexes);
}

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
    Genome::Model::Command::Update::Genotype::BayesianFullAlphabetDistributionTest->new->runtests();
}
#
##    AC?ATC*TACT-A
#
##.5  AC-TAC*TACT
##.7   C-ATC-ATCA*T
##.9        *TAGTTAG

1;
