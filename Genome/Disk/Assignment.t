#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 8;

use above 'Genome';

BEGIN {
        use_ok('Genome::Disk::Group');
        use_ok('Genome::Disk::Volume');
        use_ok('Genome::Disk::Assignment');
};

my $group = Genome::Disk::Group->get(disk_group_name => 'info_apipe');
isa_ok($group,'Genome::Disk::Group');
my $volume = Genome::Disk::Volume->get(mount_path => '/gscmnt/sata820');
isa_ok($volume,'Genome::Disk::Volume');

my $gva = Genome::Disk::Assignment->get(
dg_id => $group->dg_id,
dv_id => $volume->dv_id,
);
isa_ok($gva,'Genome::Disk::Assignment');
is($gva->group->dg_id,$group->dg_id,'disk group accessor works');
is($gva->volume->dv_id,$volume->dv_id,'disk volume accessor works');

exit;
