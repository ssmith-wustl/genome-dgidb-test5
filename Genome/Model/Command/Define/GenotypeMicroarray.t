
use strict;
use warnings;

use above "Genome";
use Genome::Model::Command::Define::GenotypeMicroarray;
use File::Slurp;
use File::Temp;
use Test::More tests => 6;

# make a model like we do on the cmdline, but with Perl
# $cmd = Genome::Model::C->
# 1. ck for a model w/ the name you gave
# 2. ck for a build
# 3. ck for a data directory w/ the file you gave (make a file in /tmp and ensure they match)


BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    use_ok("Genome::Model::Command::Define::GenotypeMicroarray");
};


my $tempdir = File::Temp::tempdir(CLEANUP => 1);
my $temp_wugc = $tempdir."/genotype-microarray-test.wugc";
#my $template = "genotype-microarray-test-". $ENV{USER} . "-XXXXXXX";
#my (undef, $temp_wugc) = File::Temp::tempfile($template,
#                                              DIR => '/tmp',
#                                              SUFFIX => '.wugc',);

my $test_model_name = "genotype-ma-test-".$ENV{USER}."-".$$;
$test_model_name ='H_KA-123172-S.3576';
my $ppid = 2166945;
my $ppname = 'illumina/wugc';

#write_file($temp_wugc,'1\t72017\tAA\n1\t311622\tAA\n1\t314893\t--\n');
write_file($temp_wugc,"1\t72017\t72017\tA\tA\tref\tref\tref\tref\n1\t311622\t311622\tG\tA\tref\tSNP\tref\tSNP\n1\t314893\t--\n");

my $gm = Genome::Model::Command::Define::GenotypeMicroarray->create(
    processing_profile_name => $ppname ,
    subject_name            => $test_model_name, 
    model_name              => $test_model_name .".test",
    data_directory          => $tempdir,
    file                    => $temp_wugc ,
);
ok($gm->execute(),'define model');

# check for the model with the name

my $model = Genome::Model->get(name => $test_model_name.".test");

is($model->name,$test_model_name.".test", 'expected test model name retrieved');

my $model_data_dir = $model->data_directory;
# check for build
my $build = Genome::Model::Build->get(model_id => $model->id);

ok(defined($build), 'we got a build object back');

# check the build directory, check the contents for the file...

ok(-d $build->data_directory, 'data directory exists');
my $orig_contents = read_file($temp_wugc);
my $dest_contents = read_file($build->data_directory."/formatted_genotype_file_path.genotype");
#formatted_genotype_file_path.genotype
is($dest_contents,$orig_contents,'original and copied files match');

# let us nuke the build and model...
$build->delete;
$model->delete;

system("rm -rf $model_data_dir");
