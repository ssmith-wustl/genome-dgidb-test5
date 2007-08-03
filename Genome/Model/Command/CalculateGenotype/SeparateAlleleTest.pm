#!/usr/bin/env perl

use strict;
use warnings;

use lib '/gsc/scripts/test/ur-dev';

package Genome::Model::Command::CalculateGenotype::SeparateAlleleTest;
use base 'Test::Class';

use Test::More;
use Test::Deep;

use Genome::Model::Command::CalculateGenotype::SeparateAllele;
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
    
    my $consensus_calc = Genome::Model::Command::CalculateGenotype::SeparateAllele->create(
            length      => 1,
            result      => $consensus_results,
    );
    $self->{consensus_calc} = $consensus_calc;
}

sub _create_mock_alignments {
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

sub test_simple_het : Test(1) {
    my $self = shift;
    my $a = _create_mock_alignments(
        [ 
            [[.7,.1,.1,.1], MATCH, 1], 
            [[.1,.1,.1,.7], MATCH, 1], 
            [[.7,.1,.1,.1], MATCH, 1], 
            [[.1,.1,.1,.7], MATCH, 1], 
            #[[1,0,0,0], MATCH, 1], 
            #[[1,0,0,0], MATCH, 1], 
        ],                               #
    );

    my $result = $self->{consensus_calc}->_examine_position($a);

    my $expect = {
        AT => .5,
        TA => .5,
    };    
    
    cmp_deeply($result,$expect, "simple perfect het");
}


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
    Genome::Model::Command::CalculateGenotype::SeparateAlleleTest->new->runtests();
}

1;
