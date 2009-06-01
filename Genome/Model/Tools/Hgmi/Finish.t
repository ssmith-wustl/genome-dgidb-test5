#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use File::Remove qw/ remove /;

use Test::More tests => 2;

BEGIN {
        use_ok('Genome::Model::Tools::Hgmi::Finish');
#        use_ok('Genome::Model::Tools::Hgmi::DirBuilder');
}

my $finish = Genome::Model::Tools::Hgmi::Finish->create(
  'organism_name' => "Bifidobacterium_catenulatum",
  'locus_tag' => "BIFCATDFT",
  'project_type' => "HGMI",
  'sequence_set_name' => "Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb",
  'acedb_version' => 'V2',
  'dev' => 1
);

isa_ok($finish, 'Genome::Model::Tools::Hgmi::Finish');

#my $d = Genome::Model::Tools::Hgmi::DirBuilder->create(
#                    path => "/tmp/test/analysis/HGMI",
#                    'org_dirname' => "B_catenulatum",
#                    'assembly_version_name' => "Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb",
#                    'assembly_version' => "1.0",
#                    'pipe_version' => "1.0",
#                    'cell_type' => "BACTERIA");
#$d->execute();

#my $res = $finish->gather_details();
#print join(" ",@$res),"\n";

# remove \1, $removepath;
