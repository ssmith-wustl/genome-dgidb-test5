#!/usr/bin/env perl

use strict;
use warnings;

use IO::File;
use Genome::Command::CalculateCoverage;


package Genome::Command::CalculateCoverageTest;
use base 'Test::Class';

use Test::Deep;

my $BINARY_ALN_FILE_PATH = '/gscmnt/sata114/info/medseq/ryan/solexa/test_data/sxog_1_22';


sub setup : Test(setup){
    my $self = shift;
    
    $self->{cov_calc} = Genome::Command::CalculateCoverage->new( binary_aln_filename => $BINARY_ALN_FILE_PATH );
}

sub test_get_coverage_by_position : Test(1){
    my $self = shift;
    
    my $temp = IO::File->new_tmpfile();
    $self->{cov_calc}->print_coverage_by_position($temp);
    
    # rewind!
    $temp->seek(0,0);
        
    my $coverage_string = '';
    while(<$temp>){
        next if m/^>/;
        chomp;
        $coverage_string .= $_;
    }
    
    my $coverage_array = [split(/\s/, $coverage_string)];
    
    my $expected_array = [ qw/0 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 3 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0/ ];
    
    cmp_deeply( $coverage_array, $expected_array, "Coverage array is caluclated correctly from binary alignment file" );
}

if( $0 eq __FILE__ ){
   Genome::Command::CalculateCoverageTest->new->runtests();
}

1;
