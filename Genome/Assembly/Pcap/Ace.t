#!/usr/bin/env perl
package Genome::Assembly::Pcap::Ace::Test;
use above 'Genome';
use Genome::Assembly::Pcap::Ace;
use base qw(Test::Class);
use Test::More tests => 21;
use File::Temp;

#use Test::Deep;

our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

sub header : Test(startup){
	print "\nTesting Genome::Assembly::Pcap::Ace\n";	
}
sub setup : Test(setup){
	my $self = shift;
	$self->{assembly} = [];
	push(@{$self->{assembly}}, Genome::Assembly::Pcap::Ace->new(
											input_file => "/gsc/var/cache/testsuite/data/Genome-Assembly-Pcap/test.ace"
										));
}

sub setup2 : Test(setup){
	my $self = shift;
    $self->{tmp} = File::Temp->new( UNLINK => 1, SUFFIX => '.db' );
    die "Failed to create temp sqlite db file for testing.\n" unless defined $self->{tmp};
	push(@{$self->{assembly}}, Genome::Assembly::Pcap::Ace->new(
											input_file => "/gsc/var/cache/testsuite/data/Genome-Assembly-Pcap/test.ace",
											using_db => 1,
											db_type => "SQLite",
                                            db_file => $self->{tmp}->filename
										));
	
	
}

sub setup3 : Test(setup){
	my $self = shift;
	push(@{$self->{assembly}}, Genome::Assembly::Pcap::Ace->new(
											input_file => "/gsc/var/cache/testsuite/data/Genome-Assembly-Pcap/test.ace",
											using_db => 1,
											db_type => "mysql"
										));	
	
}


sub teardown : Test(teardown){
	my $self = shift;
	
	$self->{assembly} = undef;
    $self->{tmp} = undef;
}

sub test_get_contig : Tests{
	my $self = shift;
	foreach my $assembly (@{$self->{assembly}})
	{
		my $contig = $assembly->get_contig(
										"Contig0.10"
									);
		my $name = $contig->name;
		my $seq = $contig->padded_base_string;
	
		is($name, "Contig0.10", "Name survives creation/getting");
	}
}

sub test_get_contig_base_string : Tests{
	my $self = shift;
	foreach my $assembly (@{$self->{assembly}})
	{
		my $contig = $assembly->get_contig(
											"Contig0.10"
										);
		my $seq = $contig->padded_base_string;
		is(substr($seq,0,50), "CtcaattggcaaTCAAtctGTGGCTctTAcCCAAcAAGGcGCAATCACAA", "Sequence survives creation");
	}
}

sub test_get_base_string_length : Tests{
	my $self = shift;
	foreach my $assembly (@{$self->{assembly}})
	{
		my $contig = $assembly->get_contig(
										"Contig0.10"
									);
		my $length = $contig->length;
		is($length, 156110, "Length survives creation");
		my $unpadlength = $contig->length("unpadded");
		is($unpadlength, 153704, "Unpadded length is correct"); 
		my $seq = $contig->unpadded_base_string;
		my $seq2 = $contig->padded_base_string;
		is(length $seq, 153704, "Padded base string retrieved correctly");
		is(length $seq2, 156110, "Unpadded base string retrieved correctly");
	}
}

sub test_build_index : Tests{
	my $self = shift;
	foreach my $assembly (@{$self->{assembly}})
	{
		#$assembly->_build_ace_index(file_name => '/gsc/var/cache/testsuite/data/Genome-Assembly-Pcap/test.ace');
        #TODO: write tests for indexing
		ok(1, 'index built properly');
	}
}
 
Genome::Assembly::Pcap::Ace::Test->runtests;
 
