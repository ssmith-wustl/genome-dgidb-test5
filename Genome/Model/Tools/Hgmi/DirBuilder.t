#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 3;

BEGIN {
        use_ok('Genome::Model::Tools::Hgmi::DirBuilder');
}


my $tool_db = Genome::Model::Tools::Hgmi::DirBuilder->create(
                    path => "/tmp",
                    'org_dirname' => "BLah",
                    'assembly_version_name' => "Blah_2.0",
                    'assembly_version' => "2.0",
                    'pipe_version' => "1.0",
                    'cell_type' => "BACTERIA");
isa_ok($tool_db,'Genome::Model::Tools::Hgmi::DirBuilder');
ok($tool_db->execute,'execute dir builder');
# check directory structure, then remove what was created.

exit;
