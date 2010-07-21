#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use File::Remove qw/ remove /;
use File::Temp qw/ tempdir/;
use English;

use Test::More tests => 3;

BEGIN {
        use_ok('Genome::Model::Tools::Hgmi::DirBuilder');
}

unless( -d "/tmp/disk/")
{
    mkdir("/tmp/disk");
}

unless( -l "/tmp/disk/analysis")
{
    symlink("/gsc/var/cache/testsuite/data/Genome-Model-Tools-Hgmi/analysis",
            "/tmp/disk/analysis");
}

my $dir = tempdir("HGMI_XXXXXX", DIR => "/tmp/disk/analysis", 
                                 CLEANUP => 1 );

#/tmp/disk/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/BAP/Version_1.0/
my $tool_db = Genome::Model::Tools::Hgmi::DirBuilder->create(
                    #path => "/tmp/disk/analysis/HGMI",
                    path => $dir,
                    'org_dirname' => "B_catenulatum",
                    'assembly_version_name' => "Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb",
                    'assembly_version' => "Version_1.0",
                    'pipe_version' => "Version_1.0",
                    'cell_type' => "BACTERIA");
isa_ok($tool_db,'Genome::Model::Tools::Hgmi::DirBuilder');
#if(-d "/tmp/disk/analysis")
#{
#    # recurively remove dir
#    remove \1, qw{ /tmp/disk/analysis };
#}
#system("mkdir -p /tmp/disk/analysis/HGMI");
ok($tool_db->execute,'execute dir builder');
# check directory structure, then remove what was created.
remove \1, qw{ $dir };

