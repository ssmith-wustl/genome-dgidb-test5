#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 28;
use File::Temp;
use File::Path;
use GSCApp;
App->init;

BEGIN {
    use_ok( 'Genome::Model::Tools::Newbler::NewMapping');
    use_ok( 'Genome::Model::Tools::Newbler::NewAssembly');
    use_ok( 'Genome::Model::Tools::Newbler::SetRef');
    use_ok( 'Genome::Model::Tools::Newbler::AddRun');
    use_ok( 'Genome::Model::Tools::Newbler::RemoveRun');
    use_ok( 'Genome::Model::Tools::Newbler::RunProject');
};

my $test = 0;
my $run_name = 'R_2008_01_09_15_15_31_FLX02070142_adminrig_85861872';
my @ids = qw(5 6 7 8);

my @run_region_454s = GSC::RunRegion454->get(
                                             run_name => $run_name,
                                             region_number => \@ids,
                                         );
is(@run_region_454s,scalar(@ids),'got GSC::RunRegion454');

my $sff_tmp_dir = File::Temp::tempdir;

print "Dumping sff files from dw to '$sff_tmp_dir'\n";
for my $run_region_454 (@run_region_454s) {
    my $filename = $sff_tmp_dir .'/'. $run_region_454->region_number .'.sff';
    ok($run_region_454->dump_sff(filename => $filename),'dump to '. $filename);
}
my @sff_files = glob($sff_tmp_dir .'/*.sff');
is(scalar(@sff_files),scalar(@ids),'the correct number of sff files dumped');

my $ref_seq_dir = '/gscmnt/839/info/medseq/reference_sequences/refseq-for-test';
my @fasta_files = glob($ref_seq_dir .'/*.fasta');


my $mapping_dir = File::Temp::tempdir;
my $new_mapping = Genome::Model::Tools::Newbler::NewMapping->create(
                                                                    dir => $mapping_dir,
                                                                    test => $test,
                                                                   );
isa_ok($new_mapping,'Genome::Model::Tools::Newbler::NewMapping');
ok($new_mapping->execute,'execute newbler newMapping');
ok(-d $mapping_dir,'directory exists');
my $set_ref = Genome::Model::Tools::Newbler::SetRef->create(
                                                            dir => $mapping_dir,
                                                            reference_fasta_files => \@fasta_files,
                                                            test => $test,
                                                        );
isa_ok($set_ref,'Genome::Model::Tools::Newbler::SetRef');
ok($set_ref->execute,'execute newbler setRef');


my $assembly_dir = File::Temp::tempdir;
my $new_assembly = Genome::Model::Tools::Newbler::NewAssembly->create(
                                                                      dir => $assembly_dir,
                                                                      test => $test,
                                                                   );
isa_ok($new_assembly,'Genome::Model::Tools::Newbler::NewAssembly');
ok($new_assembly->execute,'execute newbler newAssembly');
ok(-d $assembly_dir,'directory exists');

my @dirs = ($mapping_dir, $assembly_dir);
foreach my $dir (@dirs) {
    my $add_run = Genome::Model::Tools::Newbler::AddRun->create(
                                                                dir => $dir,
                                                                runs => \@sff_files,
                                                                test => $test,
                                                            );
    isa_ok($add_run,'Genome::Model::Tools::Newbler::AddRun');
    ok($add_run->execute,'execute newbler addRun');

    my $run_project = Genome::Model::Tools::Newbler::RunProject->create(
                                                                        dir => $dir,
                                                                        test => $test,
                                                                    );
    isa_ok($run_project,'Genome::Model::Tools::Newbler::RunProject');
    ok($run_project->execute,'execute newbler runProject');
}

#rmtree $mapping_dir || die "Could not remove directory '$mapping_dir'";
#rmtree $assembly_dir || die "Could not remove directory '$assembly_dir'";
#rmtree $sff_tmp_dir || die "Could not remove directory '$sff_tmp_dir'";

exit;
