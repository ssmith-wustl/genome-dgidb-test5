#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 6;

use above 'Genome';

BEGIN {
        use_ok('Genome::Disk::Group');
};

my $group = Genome::Disk::Group->get(disk_group_name => 'info_apipe');
isa_ok($group,'Genome::Disk::Group');
my @assignments = $group->assignments;
ok(scalar(@assignments) > 1,'more than one group/volume assignments');
isa_ok(shift(@assignments),'Genome::Disk::Assignment');
my @volumes = $group->volumes;

ok(scalar(@volumes) > 1,'more than one volume found');
isa_ok(shift(@volumes),'Genome::Disk::Volume');

exit;
