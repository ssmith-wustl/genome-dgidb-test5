#!/gsc/bin/perl

use strict;
use warnings;

use Data::Dumper;

use above "Genome";
use Test::More tests => 2;
use Genome::Utility::GeneHeader::Reader;

use FindBin qw($Bin);
my $file = "$Bin/gene_header.txt";

my $reader = Genome::Utility::GeneHeader::Reader->create(
                                                         file => $file,
                                                     );
isa_ok($reader,'Genome::Utility::GeneHeader::Reader');
ok($reader->execute,'execute');
exit;
