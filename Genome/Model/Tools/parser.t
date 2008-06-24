#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Data::Dumper;
use Genome::Model::Tools::Parser;

use Test::More tests => 5;
use Test::Differences;

my $tsv_file = 'test.tsv';
my $csv_file = 'test.csv';

#my @header = qw(build chromosome orientation start end sample allele1 allele2 comments);

my $tsv_parser = Genome::Model::Tools::Parser->create(
                                                  file => $tsv_file,
                                                  separator => "\t",
                                                  );
#$parser->header_fields(\@header);

isa_ok($tsv_parser,'Genome::Model::Tools::Parser');
ok($tsv_parser->execute(),'execute tsv parser');
my $tsv_data_ref = $tsv_parser->data_hash_ref;

my $csv_parser = Genome::Model::Tools::Parser->create(
                                                      file => $csv_file,
                                                  );
isa_ok($csv_parser,'Genome::Model::Tools::Parser');
ok($csv_parser->execute(),'execute csv parser');
my $csv_data_ref = $csv_parser->data_hash_ref;

eq_or_diff($tsv_data_ref,$csv_data_ref,'data produced by tab and comma delimited files');


exit;
