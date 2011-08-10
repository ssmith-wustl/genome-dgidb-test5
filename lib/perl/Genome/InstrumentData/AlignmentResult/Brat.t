use strict;
use warnings;

use File::Path;
use Test::More;
use Sys::Hostname;

use above 'Genome';

BEGIN {
    plan skip_all => 'Broken due to homedir dependency';
    #if (`uname -a` =~ /x86_64/) {
    #    plan tests => 31;
    #} else {
    #    plan skip_all => 'Must run on a 64 bit machine';
    #}
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    use_ok('Genome::InstrumentData::Solexa');
}


#
# Configuration for the aligner name, etc
#
###############################################################################

# this ought to match the name as seen in the processing profile
my $aligner_name = "brat";


# End aligner-specific configuration,
# everything below here ought to be generic.
#

# Override lock name because if people cancel tests locks don't get cleaned up.
*Genome::SoftwareResult::_resolve_lock_name = sub {
    return "/tmp/lock/Genome--InstrumentData--AlignmentResult--Brat/" . time();
};

#
# Gather up versions for the tools used herein
#
###############################################################################
my $aligner_tools_class_name = "Genome::Model::Tools::" . Genome::InstrumentData::AlignmentResult->_resolve_subclass_name_for_aligner_name($aligner_name);
my $alignment_result_class_name = "Genome::InstrumentData::AlignmentResult::" . Genome::InstrumentData::AlignmentResult->_resolve_subclass_name_for_aligner_name($aligner_name);

my $samtools_version = Genome::Model::Tools::Sam->default_samtools_version;
my $picard_version = Genome::Model::Tools::Picard->default_picard_version;

my $aligner_version_method_name = sprintf("default_%s_version", $aligner_name);

my $aligner_version = $aligner_tools_class_name->default_version;
my $aligner_label   = $aligner_name.$aligner_version;
$aligner_label =~ s/\./\_/g;

my $expected_shortcut_path = "/gscmnt/sata828/info/alignment_data/$aligner_label/TEST-human/test_run_name/4_-123456",

my $FAKE_INSTRUMENT_DATA_ID=-123456;
eval "use $alignment_result_class_name";

#
# Gather up the reference sequences.
#
###########################################################

my $reference_model = Genome::Model::ImportedReferenceSequence->get(name => 'TEST-human');
ok($reference_model, "got reference model");

my $reference_build = $reference_model->build_by_version('1');
ok($reference_build, "got reference build");

my $temp_reference_index = Genome::Model::Build::ReferenceSequence::AlignerIndex->create(reference_build=>$reference_build, aligner_version=>$aligner_version, aligner_name=>'brat', aligner_params=>'');

ok($temp_reference_index, "prepared temporary reference index");

my $instrument_data = generate_fake_instrument_data();
# Uncomment this to create the dataset necessary for shorcutting to work
#test_alignment(generate_shortcut_data => 1, instrument_data => $instrument_data);

test_shortcutting(instrument_data => $instrument_data);
test_alignment(validate_against_shortcut => 1, instrument_data=>$instrument_data, test_name => 'validate_shortcut_data');
# cleanup locks after testing alignment
$FAKE_INSTRUMENT_DATA_ID--;
$instrument_data = generate_fake_instrument_data();
test_alignment(force_fragment => 1, instrument_data=>$instrument_data);

sub test_alignment {
    my %p = @_;
    
    my $generate_shortcut = delete $p{generate_shortcut_data};
    my $validate_against_shortcut = delete $p{validate_against_shortcut};
    my $instrument_data = delete $p{instrument_data};

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
    $DB::single = 1;
    ok($dir, "alignments found/generated");
    ok(-d $dir, "result is a real directory");
    ok(-s $dir . "/all_sequences.bam", "result has a bam file");
    print "DIR is $dir\n";

    if ($generate_shortcut) {
        print "*** Using this data to generate shortcut data! ***\n";

        if (-d $expected_shortcut_path) {
            die "Expected shortcut path $expected_shortcut_path already exists, don't want to step on it";
        }
        mkpath($expected_shortcut_path);

        system("rsync -a $dir/* $expected_shortcut_path");
    } 

    if ($validate_against_shortcut) {
        my $generated_bam_md5 = Genome::Sys->md5sum($dir . "/all_sequences.bam");
        my $to_validate_bam_md5 = Genome::Sys->md5sum($expected_shortcut_path  . "/all_sequences.bam");
       
        print "Comparing " . $dir . "/all_sequences.bam with $expected_shortcut_path/all_sequences.bam\n\n\n"; 
        is($generated_bam_md5, $to_validate_bam_md5, "generated md5 matches what we expect -- the bam file is the same!");
        
    }

    # clear out the temp scratch/staging paths since these normally would be auto cleaned up at completion
    my $base_tempdir = Genome::Sys->base_temp_directory;
    for (glob($base_tempdir . "/*")) {
        File::Path::rmtree($_);
    }

    ok($alignment->unlock, "unlock the alignment since we're not committing");


}

sub test_shortcutting {
    my %p = @_;
    my $fake_instrument_data = delete $p{instrument_data};

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
    ok(-s $dir."/all_sequences.bam", "found a bam file in there");

    my $alignment_from_lock = Genome::InstrumentData::AlignmentResult->get_with_lock(
                                                              instrument_data_id => $fake_instrument_data->id,
                                                              aligner_name => $aligner_name,
                                                              aligner_version => $aligner_version,
                                                              samtools_version => $samtools_version,
                                                              picard_version => $picard_version,
                                                              reference_build => $reference_build,
                                                              );
    ok($alignment_from_lock, "got an alignment object using get_with_lock");
    is($alignment_from_lock, $alignment, "got same object as without locking");
}


my ($library, $sample);
sub generate_fake_instrument_data {

    if ( not $library or not $sample ) {
        $sample = Genome::Sample->create(
            name => 'test_sample_name',
        );
        ok($sample, 'create sample') or die;
        $library = Genome::Library->create(
            name => $sample->name.'-lib1',
            sample => $sample,
        );
        ok($library, 'create library');
    }

    my $fastq_directory = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Align-Maq/test_sample_name';
    my $instrument_data = Genome::InstrumentData::Solexa->create(
        id => $FAKE_INSTRUMENT_DATA_ID,
        library => $library,
        flow_cell_id => '12345',
        lane => '1',
        median_insert_size => '22',
        sd_below_insert_size => '7',
        sd_above_insert_size => '34',
        run_name => '110101_TEST',
        subset_name => 4,
        run_type => 'Paired',
        gerald_directory => $fastq_directory,
        bam_path => '/gsc/var/cache/testsuite/data/Genome-InstrumentData-AlignmentResult-Bwa/input.bam'
    );
    ok($instrument_data, 'create instrument data: '.$instrument_data->id);
    ok($instrument_data->is_paired_end, 'instrument data is paired end');

    return $instrument_data;

}
