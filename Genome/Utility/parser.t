#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Data::Dumper;
use Genome::Utility::Parser;

use Test::More tests => 7;
use Test::Differences;

# Use FindBin to provie a proper full path to the test files
# so we can run this test from anywhere
use FindBin qw($Bin);
my $tsv_file = "$Bin/test.tsv";
my $csv_file = "$Bin/test.csv";

my @header = qw(build chromosome orientation start end sample allele1 allele2 comments);

# Tests using tab delimiter
my $tsv_parser = Genome::Utility::Parser->create(
                                                  file => $tsv_file,
                                                  separator => "\t",
                                                  );
isa_ok($tsv_parser,'Genome::Utility::Parser');
is_deeply($tsv_parser->header_fields,\@header,'header parsed correctly for tsv');
ok($tsv_parser->execute(),'execute tsv parser');
my $tsv_data_ref = $tsv_parser->data_hash_ref;

# Tests using comma delimiter
my $csv_parser = Genome::Utility::Parser->create(
                                                      file => $csv_file,
                                                  );
isa_ok($csv_parser,'Genome::Utility::Parser');
is_deeply($csv_parser->header_fields,\@header,'header parsed correctly for csv');
ok($csv_parser->execute(),'execute csv parser');
my $csv_data_ref = $csv_parser->data_hash_ref;

# Test equality of tab versus comma delimited
eq_or_diff($tsv_data_ref,$csv_data_ref,'data produced by tab and comma delimited files');


exit;
