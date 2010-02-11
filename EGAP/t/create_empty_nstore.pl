use strict;
use warnings;

use above 'EGAP';

use Bio::Seq;
use Bio::SeqIO;

use Data::Dumper;
use File::Temp;
use Storable qw(nstore retrieve);

$Storable::forgive_me = 1;
$storable::Deparse    = 1;

my @array = ( );

nstore \@array, $ARGV[0];

