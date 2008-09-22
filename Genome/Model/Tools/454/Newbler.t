#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More;
use File::Temp;
use File::Path;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    }
    plan tests => 35;

    use_ok( 'Genome::Model::Tools::454::Newbler::NewMapping');
    use_ok( 'Genome::Model::Tools::454::Newbler::NewAssembly');
    use_ok( 'Genome::Model::Tools::454::Newbler::SetRef');
    use_ok( 'Genome::Model::Tools::454::Newbler::AddRun');
    use_ok( 'Genome::Model::Tools::454::Newbler::RemoveRun');
    use_ok( 'Genome::Model::Tools::454::Newbler::RunProject');
    use_ok( 'Genome::Model::Tools::454::Newbler::RunMapping');
    use_ok( 'Genome::Model::Tools::454::Newbler::RunAssembly');
};

my $test = 0;
my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-454-Newbler';

my $ref_seq_dir = '/gscmnt/839/info/medseq/reference_sequences/refseq-for-test';
my @fasta_files = glob($ref_seq_dir .'/11.fasta');
is(scalar(@fasta_files),1,'correct number of test fasta files found');

opendir(DATA,$data_dir) || die ("Can not open data directory '$data_dir'");
my @runs = grep { !/^\./  } readdir DATA;
closedir DATA;
is(scalar(@runs),1,'correct number of test runs found');
my $run_name = $runs[0];

my $run_dir = $data_dir .'/'. $run_name;
opendir(RUN,$run_dir) || die ("Can not open run directory '$run_dir'");
my @sff_files = map { $run_dir.'/'.$_ } grep { /\.sff$/  } readdir RUN;
closedir RUN;
is(scalar(@sff_files),4,'correct number of test sff files found');

my $mapping_project_dir = File::Temp::tempdir(CLEANUP => 1);
ok(rmtree($mapping_project_dir),"removed tmp directory: $mapping_project_dir");
my $new_mapping = Genome::Model::Tools::454::Newbler::NewMapping->create(
                                                                         dir => $mapping_project_dir,
                                                                         test => $test,
                                                                     );
isa_ok($new_mapping,'Genome::Model::Tools::454::Newbler::NewMapping');
ok($new_mapping->execute,'execute newbler newMapping');
ok(-d $mapping_project_dir,'newbler mapping directory created');
my $set_ref = Genome::Model::Tools::454::Newbler::SetRef->create(
                                                                 dir => $mapping_project_dir,
                                                                 reference_fasta_files => \@fasta_files,
                                                                 test => $test,
                                                             );
isa_ok($set_ref,'Genome::Model::Tools::454::Newbler::SetRef');
ok($set_ref->execute,'execute newbler setRef');


my $assembly_project_dir = File::Temp::tempdir(CLEANUP => 1);
ok(rmtree($assembly_project_dir),"removed tmp directory: $assembly_project_dir");
my $new_assembly = Genome::Model::Tools::454::Newbler::NewAssembly->create(
                                                                           dir => $assembly_project_dir,
                                                                           test => $test,
                                                                       );
isa_ok($new_assembly,'Genome::Model::Tools::454::Newbler::NewAssembly');
ok($new_assembly->execute,'execute newbler newAssembly');
ok(-d $assembly_project_dir,'newbler assembly directory created');

my @dirs = ($mapping_project_dir, $assembly_project_dir);
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

my $mapping_dir = File::Temp::tempdir(CLEANUP => 1);
ok(rmtree($mapping_dir),"removed tmp directory: $mapping_dir");
my $run_mapping = Genome::Model::Tools::454::Newbler::RunMapping->create(
                                                                         mapping_dir => $mapping_dir,
                                                                         sff_files => \@sff_files,
                                                                         ref_seq => $fasta_files[0],
                                                                         test => $test,
                                                                     );
isa_ok($run_mapping,'Genome::Model::Tools::454::Newbler::RunMapping');
ok($run_mapping->execute,'execute newbler runMapping');

my $assembly_dir = File::Temp::tempdir(CLEANUP => 1);
ok(rmtree($assembly_dir),"removed tmp directory: $assembly_dir");
my $run_assembly = Genome::Model::Tools::454::Newbler::RunAssembly->create(
                                                                           assembly_dir => $assembly_dir,
                                                                           sff_files => \@sff_files,
                                                                           test => $test,
                                                                       );
isa_ok($run_assembly,'Genome::Model::Tools::454::Newbler::RunAssembly');
ok($run_assembly->execute,'execute newbler runAssembly');

exit;
