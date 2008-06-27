#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::Heatmap;
use Test::More tests => 1;
use Digest::MD5 qw(md5_hex);
#plan "skip_all";

my $file = "t/heatmap-test-matrix.csv";
my $outfile = "t/heatmap-test-image.png";
my $columns = 3;
my $checksum = "007d3bb4cfa3bb2aacf152dcfa02aafa";

my $hm = Genome::Model::Tools::Heatmap->create(
                                                         matrix => $file,
                                                         image => $outfile,
                                                         columns => $columns,
                                                        );
ok($hm->execute,'heatmap image generation');
my $imagecontents = qw(cat $outfile);
#is(md5_hex($imagecontents), $checksum, 'image correct');

#ok(0,'firetest');


exit;

