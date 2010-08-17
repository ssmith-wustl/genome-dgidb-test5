use strict;
use warnings;

use File::Path;
use Test::More;
use Sys::Hostname;

use above 'Genome';

$ENV{'TEST_MODE'} = 1;

BEGIN {
    if (`uname -a` =~ /x86_64/) {
        plan tests => 28;
    } else {
        plan skip_all => 'Must run on a 64 bit machine';
    }
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    use_ok('Genome::InstrumentData::Solexa');
}


#
# Configuration for the aligner name, etc
#
###############################################################################

# this ought to match the name as seen in the processing profile
my $aligner_name = "rtg map x";


# End aligner-specific configuration,
# everything below here ought to be generic.
#

#
# Gather up versions for the tools used herein
#
###############################################################################

my $aligner_tools_class_name = "Genome::Model::Tools::Rtg";
my $alignment_result_class_name = "Genome::InstrumentData::AlignmentResult::" . Genome::InstrumentData::AlignmentResult->_resolve_subclass_name_for_aligner_name($aligner_name);

my $samtools_version = Genome::Model::Tools::Sam->default_samtools_version;
my $picard_version = Genome::Model::Tools::Picard->default_picard_version;

my $aligner_version_method_name = sprintf("default_%s_version", $aligner_name);

my $aligner_version = $aligner_tools_class_name->default_rtg_version;
my $aligner_label   = $aligner_name.$aligner_version;
$aligner_label =~ s/\.|\s/\_/g;

my $expected_shortcut_path = "/gscmnt/sata828/info/alignment_data/$aligner_label/TEST-human/test_run_name/4_-123456",

my $FAKE_INSTRUMENT_DATA_ID=-123456;
eval "use $alignment_result_class_name";

#
# Gather up the reference sequences.
#
###########################################################

my $reference_model = Genome::Model::ImportedReferenceSequence->get(name => 'NCBI-nr'); #'/gscmnt/sata420/info/model_data/2858801443/build103014646';
ok($reference_model, "got reference model");

my $reference_build = $reference_model->build_by_version('1');
ok($reference_build, "got reference build");

# Uncomment this to create the dataset necessary for shorcutting to work
#test_alignment(generate_shortcut_data => 1);


test_shortcutting();
test_alignment();
test_alignment(force_fragment => 1);

sub test_alignment {
    my %p = @_;
    
    my $generate_shortcut = delete $p{generate_shortcut_data};

    my $instrument_data = generate_fake_instrument_data();
    my $alignment = Genome::InstrumentData::AlignmentResult->create(
                                                       instrument_data_id => $instrument_data->id,
                                                       samtools_version => $samtools_version,
                                                       picard_version => $picard_version,
                                                       aligner_version => $aligner_version,
                                                       aligner_name => $aligner_name,
                                                       reference_build => $reference_build, 
                                                       %p,
                                                   );

    ok($alignment, "Created Alignment");
    my $dir = $alignment->alignment_directory;
    ok($dir, "alignments found/generated");
    ok(-d $dir, "result is a real directory");
    ok(-s $dir . "/alignments.txt", "result has an aligned file");
    ok(-s $dir . "/unmapped.txt", "result has an unmapped file");

    if ($generate_shortcut) {
        print "*** Using this data to generate shortcut data! ***\n";

        if (-d $expected_shortcut_path) {
            die "Expected shortcut path $expected_shortcut_path already exists, don't want to step on it";
        }
        mkpath($expected_shortcut_path);

        system("rsync -a $dir/* $expected_shortcut_path");
    } 

    # clear out the temp scratch/staging paths since these normally would be auto cleaned up at completion
    my $base_tempdir = Genome::Utility::FileSystem->base_temp_directory;
    for (glob($base_tempdir . "/*")) {
        File::Path::rmtree($_);
    }



}

sub test_shortcutting {

    my $fake_instrument_data = generate_fake_instrument_data();

    my $alignment_result = $alignment_result_class_name->__define__(
                 id => -8765432,
                 output_dir => $expected_shortcut_path,
                 instrument_data_id => $fake_instrument_data->id,
                 subclass_name => $alignment_result_class_name,
                 module_version => '12345',
                 aligner_name=>$aligner_name,
                 aligner_version=>$aligner_version,
                 samtools_version=>$samtools_version,
                 picard_version=>$picard_version,
                 reference_build => $reference_build, 
    );

    # Alignment Result is a subclass of Software Result. Make sure this is true here.
    isa_ok($alignment_result, 'Genome::SoftwareResult');


    #
    # Step 1: Attempt to create an alignment that's already been created 
    # ( the one we defined up at the top of the test case )
    #
    # This ought to fail to return anything, and set the error_message property to include
    # some info about why we failed.  
    ####################################################

    my $bad_alignment = Genome::InstrumentData::AlignmentResult->create(
                                                              instrument_data_id => $fake_instrument_data->id,
                                                              aligner_name => $aligner_name,
                                                              aligner_version => $aligner_version,
                                                              samtools_version => $samtools_version,
                                                              picard_version => $picard_version,
                                                              reference_build => $reference_build, 
                                                          );
    ok(!$bad_alignment, "this should have returned undef, for attempting to create an alignment that is already created!");
    ok($alignment_result_class_name->error_message =~ m/already have one/, "the exception is what we expect to see");


    #
    # Step 2: Attempt to get an alignment that's already created
    #
    #################################################
    my $alignment = Genome::InstrumentData::AlignmentResult->get(
                                                              instrument_data_id => $fake_instrument_data->id,
                                                              aligner_name => $aligner_name,
                                                              aligner_version => $aligner_version,
                                                              samtools_version => $samtools_version,
                                                              picard_version => $picard_version,
                                                              reference_build => $reference_build, 
                                                              );
    ok($alignment, "got an alignment object");


    # once to find old data
    my $adir = $alignment->alignment_directory;
    my @list = <$adir/*>;

    ok($alignment, "Created Alignment");
    my $dir = $alignment->alignment_directory;
    ok($dir, "alignments found/generated");
    ok(-d $dir, "result is a real directory");
    ok(-s $dir."/alignments.txt", "found a aligned file in there");
    ok(-s $dir."/unmapped.txt", "found an unaligned file in there");

}


sub generate_fake_instrument_data {

    #my $fastq_directory = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Align-Maq/test_sample_name';
    my $fastq_directory = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-AlignmentResult-RtgMapX';
    my $instrument_data = Genome::InstrumentData::Solexa->create_mock(
                                                                      id => $FAKE_INSTRUMENT_DATA_ID,
                                                                      sequencing_platform => 'solexa',
                                                                      flow_cell_id => '12345',
                                                                      lane => '1',
                                                                      seq_id => $FAKE_INSTRUMENT_DATA_ID,
                                                                      median_insert_size => '22',
                                                                      sample_name => 'test_sample_name',
                                                                      library_name => 'test_sample_name-lib1',
                                                                      run_name => 'test_run_name',
                                                                      subset_name => 4,
                                                                      run_type => 'Paired End Read 2',
                                                                      gerald_directory => $fastq_directory,
                                                                  );


    # confirm there are fastq files here, and fake the fastq_filenames method to return them
    my @in_fastq_files = glob($instrument_data->gerald_directory.'/*.txt');
    $instrument_data->set_list('dump_sanger_fastq_files',@in_fastq_files);

    # fake out some properties on the instrument data
    isa_ok($instrument_data,'Genome::InstrumentData::Solexa');
    $instrument_data->set_always('sample_type','dna');
    $instrument_data->set_always('sample_id','2791246676');
    $instrument_data->set_always('is_paired_end',1);
    ok($instrument_data->is_paired_end,'instrument data is paired end');
    $instrument_data->set_always('calculate_alignment_estimated_kb_usage',10000);
    $instrument_data->set_always('resolve_quality_converter','sol2sanger');
    $instrument_data->set_always('run_start_date_formatted','Fri Jul 10 00:00:00 CDT 2009');

    $FAKE_INSTRUMENT_DATA_ID--;

    return $instrument_data;

}
