#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More;
use File::Temp;
use File::Path;

use GSCApp;
App->init;


BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    }
    plan tests => 24;

    use_ok( 'Genome::Model::Tools::454::Newbler::NewMapping');
    use_ok( 'Genome::Model::Tools::454::Newbler::NewAssembly');
    use_ok( 'Genome::Model::Tools::454::Newbler::SetRef');
    use_ok( 'Genome::Model::Tools::454::Newbler::AddRun');
    use_ok( 'Genome::Model::Tools::454::Newbler::RemoveRun');
    use_ok( 'Genome::Model::Tools::454::Newbler::RunProject');
};

my $test = 0;

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-454-Newbler';

opendir(DATA,$data_dir) || die ("Can not open data directory '$data_dir'");
my @runs = grep { !/^\./  } readdir DATA;
closedir DATA;

is(scalar(@runs),1,'the correct number of test runs found');
my $run_name = $runs[0];

my $run_dir = $data_dir .'/'. $run_name;
opendir(RUN,$run_dir) || die ("Can not open run directory '$run_dir'");
my @sff_files = map { $run_dir.'/'.$_ } grep { /\.sff$/  } readdir RUN;
closedir RUN;

is(scalar(@sff_files),4,'the correct number of test sff files found');

my $ref_seq_dir = '/gscmnt/839/info/medseq/reference_sequences/refseq-for-test';
my @fasta_files = glob($ref_seq_dir .'/11.fasta');

my $mapping_dir = File::Temp::tempdir;
my $new_mapping = Genome::Model::Tools::454::Newbler::NewMapping->create(
                                                                         dir => $mapping_dir,
                                                                         test => $test,
                                                                     );
isa_ok($new_mapping,'Genome::Model::Tools::454::Newbler::NewMapping');
ok($new_mapping->execute,'execute newbler newMapping');
ok(-d $mapping_dir,'directory exists');
my $set_ref = Genome::Model::Tools::454::Newbler::SetRef->create(
                                                                 dir => $mapping_dir,
                                                                 reference_fasta_files => \@fasta_files,
                                                                 test => $test,
                                                             );
isa_ok($set_ref,'Genome::Model::Tools::454::Newbler::SetRef');
ok($set_ref->execute,'execute newbler setRef');


my $assembly_dir = File::Temp::tempdir;
my $new_assembly = Genome::Model::Tools::454::Newbler::NewAssembly->create(
                                                                           dir => $assembly_dir,
                                                                           test => $test,
                                                                       );
isa_ok($new_assembly,'Genome::Model::Tools::454::Newbler::NewAssembly');
ok($new_assembly->execute,'execute newbler newAssembly');
ok(-d $assembly_dir,'directory exists');

my @dirs = ($mapping_dir, $assembly_dir);
foreach my $dir (@dirs) {
    my $add_run = Genome::Model::Tools::454::Newbler::AddRun->create(
                                                                     dir => $dir,
                                                                     runs => \@sff_files,
                                                                     test => $test,
                                                                 );
    isa_ok($add_run,'Genome::Model::Tools::454::Newbler::AddRun');
    ok($add_run->execute,'execute newbler addRun');

    my $run_project = Genome::Model::Tools::454::Newbler::RunProject->create(
                                                                             dir => $dir,
                                                                             test => $test,
                                                                         );
    isa_ok($run_project,'Genome::Model::Tools::454::Newbler::RunProject');
    ok($run_project->execute,'execute newbler runProject');
}

rmtree $mapping_dir || die "Could not remove directory '$mapping_dir'";
rmtree $assembly_dir || die "Could not remove directory '$assembly_dir'";

exit;
