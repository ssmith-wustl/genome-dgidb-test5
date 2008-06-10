use warnings;
use strict;

use Test::More;

#plan tests => 7;
plan skip_all => 'This test depends on a test model which is no longer present.  Replace.';

use above "Genome";
use Genome::Model::Command::Write::GenotypeSubmission;
use MG::IO::GenotypeSubmission;

my $path = $INC{"Genome.pm"};
$path =~ s/Genome.pm// or die;
require $path . "Genome/t/MaqSubmissionWriterControl.pm";

my $model = Genome::Model->get(5);
my $base_path = $model->data_directory;
my $ref_bfa = "/gscmnt/sata114/info/medseq/reference_sequences/CCDS_nucleotide.20070227.merged_new/all_sequences.bfa";
my $coord_trans = "/gscmnt/sata114/info/medseq/reference_sequences/CCDS_nucleotide.20070227.merged_new/coord_translation_all_sequences.tsv";


my $working_mg_write_gs_call_list;
my $working_mg_load_db_call;
do {
    no warnings;

########
# Capture calls to write submission files and spool them up for later comparison
########
*Genome::Model::Command::Write::GenotypeSubmission::Write = sub {
        # first parameter into here is a filehandle.  get rid of that.
        # also, copy @_ into something else to avoid all sorts of black magic going on under the hood.
       my @in = @_;
       shift @in;
       push @$working_mg_write_gs_call_list, \@in;
};
########
# stop the old code from trying to open a real filehandle on the filesystem
# make it with a "real" filehandle so the calls to close it that happen in the code
# still work
########
*Genome::Model::Command::Write::GenotypeSubmission::Open = sub {
     my $fh;
     my $blah = '';
     open ($fh, '>', \$blah);
     return $fh;
};

########
# Capture calls to load the database and save them for later comparison
########

*MG::IO::GenotypeSubmission::LoadDatabase = sub {
    $working_mg_load_db_call->{mutations} = shift;
    my %in = @_;
    for ('source', 'tech_type', 'mapping_reference', 'run_identifier') {
        $working_mg_load_db_call->{$_} = $in{$_};
    }
};
};



my $old_command = MaqSubmissionWriterControl->create(
    verbose=>1,
    source=>'wugsc',
    techtype=>'solexa',
    mappingreference=>'ccds_merged',
    cnsfile=>"$base_path/consensus/all_sequences.cns",
    mapfile=>"$base_path/alignments.submap/all_sequences.map",
    refbfa=>$ref_bfa,
    sample=>$model->sample_name,
    coordinates=>$coord_trans,
    basename=>"/tmp/TEST",
    loaddb=>1,
    runidentifier=>"1", # the new one counts runs up and we only have one run in the test model
    );  

my @old_call_set;
$working_mg_write_gs_call_list = \@old_call_set;

my %old_mutation_load_set = ();
$working_mg_load_db_call = \%old_mutation_load_set;
ok($old_command->execute, 'old write/load command executed ok');

$DB::single = 1;

ok(-f '/tmp/TEST_genotype.csv', 'test genotype file exists, we assume this is ok if the write calls matched for everything downstream');
ok(unlink('/tmp/TEST_genotype.csv'), 'removed the genotype csv file');

my $new_command = Genome::Model::Command::Write::GenotypeSubmission::Maq->create(
    model_id=>5,
    ref_seq_id=>'all_sequences'
    );

my $new_load_command = Genome::Model::Command::AddReads::UploadDatabase::Maq->create(
    model_id=>5,
    ref_seq_id=>'all_sequences'
    );

my @new_call_set;
$working_mg_write_gs_call_list = \@new_call_set;
my %new_mutation_load_set = ();
$working_mg_load_db_call = \%new_mutation_load_set;

ok($new_command->execute, 'new write command executed ok');
ok($new_load_command->execute, 'new load command executed ok');

unless (is_deeply(\@old_call_set, \@new_call_set, "write calls between new and old are identical. we rock!")) {
    unless (-d "/tmp/genome_model_write_genotype_submission") {
        mkdir "/tmp/genome_model_write_genotype_submission";
    }
    my $old_data_file = "/tmp/genome_model_write_genotype_submission/old_calls";
    my $new_data_file = "/tmp/genome_model_write_genotype_submission/new_calls";
    YAML::DumpFile($old_data_file, \@old_call_set);
    YAML::DumpFile($new_data_file, \@new_call_set);
    print "kdiff3 $old_data_file $new_data_file\n";
}

unless (is_deeply(\%old_mutation_load_set, \%new_mutation_load_set, "mutation info that would have been loaded between new and old are identical. sweet!")) {
    unless (-d "/tmp/genome_model_write_genotype_submission") {
        mkdir "/tmp/genome_model_write_genotype_submission";
    }
    my $old_data_file = "/tmp/genome_model_write_genotype_submission/load_mutations_old";
    my $new_data_file = "/tmp/genome_model_write_genotype_submission/load_mutations_new";
    YAML::DumpFile($old_data_file, \%old_mutation_load_set);
    YAML::DumpFile($new_data_file, \%new_mutation_load_set);
    print "kdiff3 $old_data_file $new_data_file\n";
}
