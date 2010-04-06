#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::WorkOrderItem');

#
# Caveats
#  USING REAL PROD DATA!
#  NOT testing a work order that does not have seq products
#   Couldn't find one easily
#  Numbers of inst data models can change, so not testing exact count or names/ids
#   It is also possible that hesee model may get deleted, in which case this test will
#   fail.
#

#< This is a work order item that has 8 sanger runs and a model
# woi id
#  2642
# inst data ids
#  21jul09.909pmcb1
#  21jul09.906pmab2
#  21jul09.906pmaa2
#  21jul09.906pmaa1
#  21jul09.909pmca1
#  21jul09.909pmca2
#  21jul09.909pmcb2
#  21jul09.906pmab1
# model
#   2852891065
my $woi = Genome::WorkOrderItem->get(2642);
ok($woi, 'Got work order item');

my @sequence_products = $woi->sequence_products;
ok(@sequence_products, 'got woi sequence products');
#print Dumper({ map { $_->prep_group_id => 1 } @sequence_products });

my @models = $woi->models;
ok(@models, 'Got at models for sanger work order');
#print Dumper(\@models);
#>


#< This is a work order item that has 454 data runs and a model
# woi_id
#  141
# inst data ids 
#  2852539831
# model
#  2744704120
$woi = Genome::WorkOrderItem->get(141);
ok($woi, 'Got work order item w/ 454 indexed regions');

@sequence_products = $woi->sequence_products;
ok(@sequence_products, 'got woi sequence products');
#print Dumper(@sequence_products);

@models = $woi->models;
ok(@models, 'Got at models for 454 work order');
#print Dumper(\@models);
#>

done_testing();
exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

