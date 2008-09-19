#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::Heatmap;
use Test::More tests => 2;
use Digest::MD5 qw(md5_hex);
use FindBin qw/$Bin/;
#plan "skip_all";

my $file = "$Bin/t/heatmap-test-matrix.csv";
my $outfile = "$Bin/t/heatmap-test-image.png";
my $columns = 3;
my $checksum = "007d3bb4cfa3bb2aacf152dcfa02aafa";

unlink $outfile;

my $hm = Genome::Model::Tools::Heatmap->create(
                                                         matrix => $file,
                                                         image => $outfile,
                                                         columns => $columns,
                                                        );
ok($hm->execute,'heatmap image generation');
ok((-e $outfile), 'output file exists');

#my $imagecontents = qx(cat $outfile);
#is(md5_hex($imagecontents), $checksum, 'image correct');
#ok(0,'firetest');

unlink $outfile;

exit;

