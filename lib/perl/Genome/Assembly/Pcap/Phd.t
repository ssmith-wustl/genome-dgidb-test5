#!/usr/bin/env perl
package Genome::Assembly::Pcap::Phd::Test;
use above 'Genome';
use Genome::Assembly::Pcap::Phd;
use base qw(Test::Class);
use Test::More tests => 1;

my $po = Genome::Assembly::Pcap::Phd->new(input_directory => '/gsc/var/cache/testsuite/data/Genome-Assembly-Pcap/phd_dir');

my $phd = $po->get_phd("L25990P6007H3.g1.phd.1");
is($phd->name,"L25990P6007H3.g1","Phd name survives creation");


