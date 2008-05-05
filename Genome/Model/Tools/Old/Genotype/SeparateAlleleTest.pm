#!/usr/bin/env perl

use strict;
use warnings;

use lib '/gsc/scripts/test/ur-dev';

package Genome::Model::Tools::Old::Genotype::SeparateAlleleTest;
use base 'Test::Class';

use Test::More;
use Test::Deep;

use Genome::Model::Tools::Old::Genotype::SeparateAllele;
use Genome::Model::RefSeqAlignmentCollection;
use Genome::Model::Alignment::Mock;

use constant MATCH              => 0;
use constant MISMATCH           => 1;
use constant QUERY_INSERT       => 3;
use constant REFERENCE_INSERT   => 2;

sub setup : Test(setup){
    my $self = shift;
    
    my $consensus_results = [];
    $self->{consensus_results} = $consensus_results;
    
    my $consensus_calc = Genome::Model::Tools::Old::Genotype::SeparateAllele->create(
            length      => 1,
            result      => $consensus_results,
    );
    $self->{consensus_calc} = $consensus_calc;
}

sub create_mock_alignments {
    my $configs = shift;
    return [
      map {
          Genome::Model::Alignment::Mock->new(
                read_bases_probability_vectors => [ $_->[0] ],
                mismatch_code                  => $_->[1],
                probability                    => $_->[2],
            )->get_current_aligned_base()
          }
      @$configs
    ];
}

sub cmp_alignments_vs_expected {
    my $self = shift;
    my $alignment_data = shift;
    my $expected = shift;
    my $msg = shift;
    
    my $mock_a = create_mock_alignments($alignment_data);
    my $result = $self->{consensus_calc}->_examine_position($mock_a);

    my @pretty = (qw/- A C G T/);
    my %result_pretty;
    my @pairs;
    for my $m (0..4) {
        for my $p (0..4) {
            my $pair = $pretty[$m] . $pretty[$p];
            push @pairs, $pair;
            $result_pretty{$pair} = $result->[$m][$p] if $result->[$m][$p];
        }
    } 
    
    cmp_deeply(\%result_pretty,$expected,$msg);
    #or (
    #    print Data::Dumper::Dumper($alignment_data)
    #    &&
    #    $self->{consensus_calc}->_print_diploid($result)
    #);

    is(sum_struct($result),1, "$msg sums to 1"); 
}

sub test_lots : Test(2) {
    my $self = shift;
    
    $self->cmp_alignments_vs_expected(
        [ 
            [[1,0,0,0], MATCH, 1], 
            [[0,0,0,1], MATCH, 1],
        ],
        {
            AT => .5,
            TA => .5,
        },
        "perfect het" 
    );

    $self->cmp_alignments_vs_expected(
        [ 
            [[1,.0,0,0], MATCH, 1], 
        ],
        {
        },
        "single perfect read" 
    );
    
    $self->cmp_alignments_vs_expected(
        [ 
            [[.25,.25,.25,.25], MATCH, 1], 
        ],
        {
        },
        "clear as mud" 
    );
}

# Add these...

# the more As in the pair the better
#[[1,0,0,0], MATCH, 1], 

# increasingly so...
#[[1,0,0,0], MATCH, 1], 
#[[1,0,0,0], MATCH, 1], 

# clear as mud
#[[.25,.25,.25,.25], MATCH, 1],

#[[.9,0,0,.1], MATCH, 1], 
#[[.1,0,0,.9], MATCH, 1], 

# AA<.5 TA=small AT=small A*=tiny T*=tiny TT>0 
#[[.9,0,0,.1], MATCH, 1], 
#[[.9,0,0,.1], MATCH, 1], 


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

if ($0 eq __FILE__){
    Genome::Model::Tools::Old::Genotype::SeparateAlleleTest->new->runtests();
}

1;
