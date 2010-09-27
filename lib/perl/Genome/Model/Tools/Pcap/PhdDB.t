#!/usr/bin/env perl
package Genome::Model::Tools::Pcap::PhdDB::Test;
use above 'Genome';
use Genome::Model::Tools::Pcap::PhdDB;
use base qw(Test::Class);
use Test::More tests => 1;

my $po = Genome::Model::Tools::Pcap::PhdDB->new;

my $phd = $po->get_phd("TPAA-afs51h08.g1.phd.1");
is($phd->name,"TPAA-afs51h08.g1","Phd name survives creation");


