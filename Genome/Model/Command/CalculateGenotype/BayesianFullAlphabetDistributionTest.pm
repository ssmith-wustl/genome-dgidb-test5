#!/usr/bin/env perl

use strict;
use warnings;

use Genome::Model::RefSeqAlignmentCollection;

package Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistributionTest;
use base 'Test::Class';

use Test::More;
use Test::Deep;

sub setup : Test(setup){
    my $self = shift;
    
    my $refseq_aln_coll = Genome::Model::RefSeqAlignmentCollection->new(
        
    );
    
    my $consensus_calc = Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistribution->new(
            bases_file  => ,
            aln         => ,
            length      => 3,
    );
}

sub test_ : Test(1) {
    
}

if ($0 eq __FILE__){
    Genome::Model::Command::CalculateGenotype::BayesianFullAlphabetDistributionTest->new->runtests();
}

