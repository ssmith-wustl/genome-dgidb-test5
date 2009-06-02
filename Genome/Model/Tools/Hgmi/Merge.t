#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use File::Remove qw/ remove /;

use Test::More tests => 5;

BEGIN {
        use_ok('Genome::Model::Tools::Hgmi::Merge');
        use_ok('Genome::Model::Tools::Hgmi::DirBuilder');
}
my $testpath = '/tmp/disk/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/BAP/Version_1.0';
system("mkdir -p /tmp/disk/analysis/HGMI");

my $d = Genome::Model::Tools::Hgmi::DirBuilder->create(
                    'path' => "/tmp/disk/analysis/HGMI",
                    'org_dirname' => "B_catenulatum",
                    'assembly_version_name' => "Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb",
                    'assembly_version' => "Version_1.0",
                    'pipe_version' => "Version_1.0",
                    'cell_type' => "BACTERIA");
isa_ok($d,'Genome::Model::Tools::Hgmi::DirBuilder');
ok($d->execute());
chdir($testpath);

my $m = Genome::Model::Tools::Hgmi::Merge->create(
  'organism_name' => "Bifidobacterium_catenulatum",
  'locus_tag' => "BIFCATDFT",
  'project_type' => "HGMI",
  'work_directory' => $testpath,
  'dev' => 1
 );

isa_ok($m,'Genome::Model::Tools::Hgmi::Merge');



#my $cmd = $m->gather_details();
my @cmd = $m->gather_details();
#$DB::single = 1;
print join(" ", @{$cmd[0]}),"\n";

remove \1, qw{ /tmp/disk/analysis };
