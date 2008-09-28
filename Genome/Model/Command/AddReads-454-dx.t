#!/gsc/bin/perl

use strict;
use warnings;
use Carp;
use File::Temp;
use File::Basename;
use Test::More;

use above "Genome";
use Genome::Model::Command::Build::ReferenceAlignment::Test;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
}
plan tests => 152;

my $tmp_dir = File::Temp::tempdir();
my $model_name = "test_454_$ENV{USER}";
my $sample_name = 'TSP_Round1-4_Normal_Amplicon_Pool';
my $pp_name = '454_DX_Pipeline';

my @read_sets = setup_test_data($sample_name);
#GSC::RunRegion454->get(sample_name => $sample_name);
my $add_reads_test = Genome::Model::Command::Build::ReferenceAlignment::Test->new(
                                                                 model_name => $model_name,
                                                                 sample_name => $sample_name,
                                                                 processing_profile_name => $pp_name,
                                                                 read_sets => \@read_sets
                                                             );
$add_reads_test->add_directory_to_remove($tmp_dir);
$add_reads_test->runtests;
exit;


sub setup_test_data {
    my $sample_name = shift;
    my @read_sets;
    chdir $tmp_dir;
    my $zip_file = '/gsc/var/cache/testsuite/data/Genome-Model-Command-AddReads/addreads-454.tgz';
    `tar -xzf $zip_file`;

    my @run_dirs = grep { -d $_ } glob("$tmp_dir/R_2008_07_29_*");
    for my $run_dir (@run_dirs) {
        my $run_name = basename($run_dir);
        my $analysis_name = $run_name . $ENV{USER} . $$;
        $analysis_name =~ s/^R/D/;
        my @files = grep { -e $_ } glob("$run_dir/*.sff");
        for my $file (@files) {
            $file =~ /(\d+)\.sff/;
            my $region_number = $1;
            my $rr454 = GSC::RunRegion454->create(
                                                  analysis_name   => $analysis_name,
                                                  incoming_dna_name => $sample_name,
                                                  region_number  => $region_number,
                                                  run_name       => $run_name,
                                                  sample_name    => $sample_name,
                                                  total_key_pass => -1,
                                                  total_raw_wells => -1,
                                                  copies_per_bead => -1,
                                                  key_pass_wells => -1,
                                                  library_name => 'TESTINGLIBRARY',
                                                  #region_id => -1,
                                                  fc_id => -2040001,
                                              );
            my $sff454 = GSC::AnalysisSFF454->create_from_sff_file(
                                                                   region_id => $rr454->region_id,
                                                                   sff_file => $file,
                                                               );
            push @read_sets, $rr454;
        }
    }
    #UR::Context->_sync_databases();
    return @read_sets;
}
