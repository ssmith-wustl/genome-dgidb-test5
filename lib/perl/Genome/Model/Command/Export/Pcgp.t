#!/usr/bin/env perl
use strict;
use warnings;
BEGIN { $ENV{'UR_USE_DUMMY_AUTOGENERATED_IDS'} = 1 };
use above "Genome";
use Test::More tests => 14;


my $p = Genome::Individual->create(name => 'TEST-patient', common_name => 'TESTpatient');
ok($p, "created patient");

my $s = Genome::Sample->create(name => 'TEST-patient-sample', common_name => 'tumor', source => $p);
ok($s, "created sample");

class Genome::ProcessingProfile::TestPcgp { 
    is => 'Genome::ProcessingProfile', 
    has_param => ['foo','bar','baz'],
};
ok(Genome::ProcessingProfile::TestPcgp->__meta__, "create processing profile type/class");

my $pp = Genome::ProcessingProfile::TestPcgp->create(name => "test pcgp export profile", foo => 123, bar => 456, baz => 789);
ok($pp, "create processing profile") or diag Genome::ProcessingProfile::TestPcgp->error_message();

my $m = Genome::Model->create(name => "test pcgp export model", processing_profile => $pp, subject_class_name => ref($s), subject_id => $s->id);
ok($m, "created model");

my $tmp = Genome::Utility::FileSystem->create_temp_directory();

my $build_id = $$;
my $data_directory = "$tmp/build$build_id";

my $b = Genome::Model::Build->create(id => $build_id, model => $m, data_directory => $data_directory);
ok($b, "created a build");

is($b->data_directory, $data_directory, "data directory is correct");
mkdir $data_directory;
ok((-d $data_directory), "data dir present");
Genome::Utility::FileSystem->create_directory("$data_directory/alignments/");
Genome::Utility::FileSystem->write_file("$data_directory/alignments/${build_id}_merged_rmdup.bam", "$$");

sub e {
    Genome::Utility::FileSystem->shellcmd(cmd => "/bin/rm -rf pcgp-upload") if -e 'pcgp-upload';
    Genome::Model::Command::Export::Pcgp->execute(paths => [@_])->result;
}

ok(chdir($tmp), "working in $tmp") or die "failed to create temp dir!";

for my $build (
    $b, 
    # uncomment to test on a real PCGP BAM (safe, but reads from db)
    # Genome::Model::Build->get(104502554) 
) {
    $build_id = $build->id;
    eval {
        ok(!e("junk"),                                              "fails with bogus path");
        ok(e($build->data_directory . "/${build_id}_merged_rmdup.bam"), "works with a full path");
        ok(e($build_id),                                            "works with a build id");
        ok(e("junk/build$build_id/junk"),                           "works with part of a build path");
        ok(e("${build_id}_merged_rmdup.bam"),                       "works with part of a bam file name");
    };
}

# ensure /tmp/? can clean up
chdir "/";

