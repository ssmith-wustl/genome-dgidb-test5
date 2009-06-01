#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use File::Remove qw/ remove /;

use Test::More tests => 5;

BEGIN {
        use_ok('Genome::Model::Tools::Hgmi::Predict');
        use_ok('Genome::Model::Tools::Hgmi::DirBuilder');
}


# do a create and then a gather_details
# check output from each one...

my $testpath = '/tmp/disk/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/BAP/Version_1.0';
#system("mkdir -p $testpath");
system("mkdir -p /tmp/disk/analysis/HGMI");
my $d = Genome::Model::Tools::Hgmi::DirBuilder->create(
                    path => "/tmp/disk/analysis/HGMI",
                    'org_dirname' => "B_catenulatum",
                    'assembly_version_name' => "Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb",
                    'assembly_version' => "Version_1.0",
                    'pipe_version' => "Version_1.0",
                    'cell_type' => "BACTERIA");
isa_ok($d,'Genome::Model::Tools::Hgmi::DirBuilder');

ok($d->execute());
# now chdir up the path
#chdir("/tmp/test/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/Sequence/Unmasked");
# do seq gather

# do chg seq name

# do model creation
my $p = Genome::Model::Tools::Hgmi::Predict->create(
  'organism_name' => "Bifidobacterium_catenulatum",
  'locus_tag' => "BIFCATDFT",
  'project_type' => "HGMI",
  'work_directory' => $testpath,
  'dev' => 1
);

isa_ok($p, 'Genome::Model::Tools::Hgmi::Predict');
#symlink("/gscmnt/278/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/BAP/Version_1.0/Sequence/BIFCATDFT.v1.contigs.newname.fasta", "/tmp/disk/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/BAP/Version_1.0/Sequence/BIFCATDFT.v1.contigs.newname.fasta");
#symlink("/gscmnt/temp212/info/annotation/gmhmmp_models/heu_11_56.mod","/tmp/disk/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/BAP/Version_1.0/heu_11_56.mod");
#my $cmd = $p->gather_details();
#print join(" ",@$cmd),"\n";

remove \1, "/tmp/disk/analysis";
