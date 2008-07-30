#!/gsc/bin/perl

use strict;
use warnings;
use Carp;

use GSCApp;

use above "Genome";
use Genome::Model::Command::AddReads::Test;

my $model_name = "test_454_$ENV{USER}";
my $sample_name = 'TSP_Round1-4_Normal_Amplicon_Pool';
my $pp_name = '454_DX_Pipeline';

my @read_sets = GSC::RunRegion454->get(sample_name => $sample_name);
my $add_reads_test = Genome::Model::Command::AddReads::Test->new(
                                                                 model_name => $model_name,
                                                                 sample_name => $sample_name,
                                                                 processing_profile_name => $pp_name,
                                                                 read_sets => \@read_sets
                                                             );
#$add_reads_test->add_directory_to_remove($dir);
$add_reads_test->runtests;
exit;
