#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 2;
use File::Path;


BEGIN
{
    use_ok ('Genome::Model::Tools::Fasta::FilterById');
}

my $fasta_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fasta-FilterById/short.fna';
my $filter_list = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fasta-FilterById/454_crossmatch.filter';
my $output_file = Genome::Sys->create_temp_file_path('clean.fna');

my $filter_by_id = Genome::Model::Tools::Fasta::FilterById->create(fasta_file=>$fasta_file,filter_list=>$filter_list,output_file=>$output_file);

my $out = $filter_by_id->execute;
ok ($out, "filter_by_id runs ok");
