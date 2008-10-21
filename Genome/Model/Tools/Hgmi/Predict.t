#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use File::Remove qw/ remove /;

use Test::More tests => 2;

BEGIN {
        use_ok('Genome::Model::Tools::Hgmi::Predict');
        use_ok('Genome::Model::Tools::Hgmi::DirBuilder');
}


# do a create and then a gather_details
# check output from each one...
my $p = Genome::Model::Tools::Hgmi::Predict->create(
  'organism_name' => "Bifidobacterium_catenulatum",
  'hgmi_locus_tag' => "BIFCATDFT",
  'project_type' => "HGMI",
  'dev' => 1
);

isa_ok($p, 'Genome::Model::Tools::Hgmi::Predict');

#my $testpath = '/tmp/disk/analysis/TEST/Species/buildname/Version_1.0/BAP/Version_1.0';
#system("mkdir -p $testpath");
system("mkdir -p /tmp/test/analysis/HGMI");
my $d = Genome::Model::Tools::Hgmi::DirBuilder->create(
                    path => "/tmp/test/analysis/HGMI",
                    'org_dirname' => "B_catenulatum",
                    'assembly_version_name' => "Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb",
                    'assembly_version' => "1.0",
                    'pipe_version' => "1.0",
                    'cell_type' => "BACTERIA");
isa_ok($d,'Genome::Model::Tools::Hgmi::DirBuilder');

$d->execute();
# now chdir up the path
chdir("/tmp/test/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/Sequence/Unmasked");
# do seq gather

# do chg seq name

# do model creation

my $cmd = $p->gather_details();
print join(" ",@$cmd),"\n";

#remove \1, $testpath;
remove \1, "/tmp/test/analysis";
