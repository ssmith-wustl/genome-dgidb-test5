#!/usr/bin/env perl
package Genome::Assembly::Pcap::PhdDB::Test;
use above 'Genome';
use Genome::Assembly::Pcap::PhdDB;
use base qw(Test::Class);
use Test::More tests => 1;

my $po = Genome::Assembly::Pcap::PhdDB->new;

my $phd = $po->get_phd("TPAA-afs51h08.g1.phd.1");
is($phd->name,"TPAA-afs51h08.g1","Phd name survives creation");


