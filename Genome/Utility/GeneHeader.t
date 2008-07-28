#!/gsc/bin/perl

use strict;
use warnings;

use Data::Dumper;

use above "Genome";
use Test::More tests => 2;
use Genome::Utility::GeneHeader::Reader;

my $file = 'gene_header.txt';
my $reader = Genome::Utility::GeneHeader::Reader->create(
                                                         file => $file,
                                                     );
isa_ok($reader,'Genome::Utility::GeneHeader::Reader');
ok($reader->execute,'execute');
exit;
