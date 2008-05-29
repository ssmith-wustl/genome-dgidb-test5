#!/gsc/bin/perl

############################
# New Add Reads test suite
############################


use strict;
use warnings;

use Data::Dumper;
use above "Genome";
use Command;

#####DEFINE TEST NUMBER HERE####
use Test::More qw(no_plan);
use Test::Differences;
###############################

my $COUNTER = -999999;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

#UR::DataSource->use_dummy_autogenerated_ids(1);


####If we have a test gzip of files, we need to unzip it here

####Maybe create Genome::RunChunk(s)?
###teh gzips are teh key here.... DR. SCHUSTE has provided us with some suitably tiny fastqs in gzip form.
###Genome/t/addreads.gzip


####Attributes for new model
####Will soon use a processsing profile, but should still have accessors to all of the below attributes
##refseq-for-test is some kinda directory that already exists with some real tiny refs... super sweet.

my $indel_finder = 'maq0_6_3';
my $model_name = "test_$ENV{USER}";
my $sample = 'H_GV-933124G-skin1-9017g';
my $dna_type = 'genomic dna';
my $align_dist_threshold = '0';
my $reference_sequence = 'refseq-for-test';
my $genotyper = 'maq0_6_3';
my $read_aligner = 'maq0_6_3';


####### test command create.

my $create_command= Genome::Model::Command::Create->create( 
    indel_finder          => $indel_finder,
    dna_type              => $dna_type,
    reference_sequence    => $reference_sequence,
    align_dist_threshold  => $align_dist_threshold,
    model_name            => $model_name,
    sample                => $sample,
    read_aligner          => $read_aligner, 
    genotyper             => $genotyper ,
); 
    
isa_ok($create_command,'Genome::Model::Command::Create');

my $result = $create_command->execute();
ok($result, 'execute genome-model create');

my $genome_model_id = $result->id;

UR::Context->_sync_databases();

my @models = Genome::Model->get($genome_model_id);
is(scalar(@models),1,'expected one model');

my $model = $models[0];
isa_ok($model,'Genome::Model');

is($model->genome_model_id,$genome_model_id,'genome_model_id accessor');
is($model->indel_finder_name,$indel_finder,'indel_finder accessor');
is($model->name,$model_name,'model_name accessor');
is($model->sample_name,$sample,'sample accessor');
is($model->dna_type,$dna_type,'dna_type accessor');
is($model->align_dist_threshold,$align_dist_threshold,'align_dist_threshold accessor');
is($model->reference_sequence_name,$reference_sequence,'reference_sequence accessor');
is($model->genotyper_name,$genotyper,'genotyper accessor');
is($model->read_aligner_name,$read_aligner,'read_aligner accessor');


exit;
###genome model add-reads section

###RUN ADD-READS. This should make scheduled

my $add_reads_event_id = get_id();
my $add_reads_command= Genome::Model::Command::AddReads->create(
                                                                id => $add_reads_event_id,
                                                                model_id => $genome_model_id,
                                                                #read_set_id => #TODO,
                                                            );

ok($add_reads_command->execute(),'execute genome-model add-reads');

####TODO: TESTING LINE-> verify scheduled the expected number and kind of steps...
my @events = Genome::Model::Event->get(model_id => $genome_model_id);

is(scalar(@events),4,'scheduled genome_model_events');

# sort by event id to ensure order of events matches pipeline order
@events = sort {$a->genome_model_event_id <=> $b->genome_model_event_id} @events;

my $assign_run_command = $events[0];
isa_ok($assign_run_command,'Genome::Model::Command::AddReads::AssignRun::Solexa');

my $assign_run_command_model = $assign_run_command->model;
eq_or_diff($model,$assign_run_command_model,'genome model comparison');

my $run = $assign_run_command->run;
isa_ok($run,'Genome::RunChunk');
#TODO: Depends on what read_set_id used above

my $data_directory = $assign_run_command->model->data_parent_directory;
ok(!-e $data_directory, 'data directory not created yet');

my $run_directory = $assign_run_command->resolve_run_directory;
ok(!-e $run_directory, 'run directory not created yet');

my $adaptor_file = $assign_run_command->adaptor_file_for_run;
ok(!-e $adaptor_file, 'adaptor_file not created yet');

my $orig_unique_file = $assign_run_command->original_sorted_unique_fastq_file_for_lane;
ok(-s $orig_unique_file, 'orig_unique_file exists from CQADR with non-zero size');

my $our_unique_file = $assign_run_command->sorted_unique_fastq_file_for_lane;
ok(!-e $our_unique_file, 'our_unique_file not created yet');

my $orig_duplicate_file = $assign_run_command->original_sorted_duplicate_fastq_file_for_lane;
ok(-s $orig_duplicate_file, 'orig_duplicate_file exists from CQADR with non-zero size');

my $our_duplicate_file = $assign_run_command->sorted_duplicate_fastq_file_for_lane;
ok(!-e $our_duplicate_file, 'our_duplicate_file not created yet');

ok($assign_run_command->execute(),'execute genome-model add-reads assign-run solexa');

ok(-d $data_directory, 'data_directory created');
ok(-d $run_directory, 'run_directory created');
ok(-f $adaptor_file, 'adaptor_file created');
ok(-l $our_unique_file, 'our_unique_file symlink created');
ok(-l $our_duplicate_file, 'our_duplicate_file symlink created');


###RUN ALIGN-READS VIA BSUBHELPER(?). 
my $align_reads_command = $events[1];
isa_ok($align_reads_command,'Genome::Model::Command::AddReads::AlignReads::Maq');

my $align_reads_command_model = $align_reads_command->model;
eq_or_diff($model,$align_reads_command_model,'genome model comparison');

$run = $align_reads_command->run;
isa_ok($run,'Genome::RunChunk');
#TODO: Depends on what read_set_id used above

my $align_reads_ref_seq_file =  $align_reads_command_model->reference_sequence_path . "/all_sequences.bfa";
#If the files are binary then the size of an empty file is greater than zero(20?)
ok(-s $align_reads_ref_seq_file, 'align-reads reference sequence file exists with non-zero size');

#TODO: SOME SORT OF TESTING FLAG SHOULD BE PASSED TO PREVENT BSUBS ILLICIT COMMITTING ACTIVITY
ok($align_reads_command->execute_with_bsub(test => 1),'execute_with_bsub genome-model add-reads align-reads maq');


#TODO: TEST THE RESULT OF ALIGN READS
#Compare the map file to the test data


###RUN PROCESS-LOW-QUAL VIA BSUBHELPER(?). 

my $proc_low_qual_command=$events[2];
isa_ok($proc_low_qual_command,'Genome::Model::Command::AddReads::ProcessLowQualityAlignments::Maq');

$run = $proc_low_qual_command->run;
isa_ok($run,'Genome::RunChunk');
ok($proc_low_qual_command->execute_with_bsub(test => 1),'execute_with_bsub genome-model add-reads process-low-quality-alignments maq');


#TODO:Test the result 
###RUN ACCEPT-READS VIA BSUBHELPER(but not really on a blade?). 

my $accept_reads_command=$events[3];

#TODO: SOME SORT OF TESTING FLAG SHOULD BE PASSED TO PREVENT BSUBS ILLICIT COMMITTING ACTIVITY
ok($accept_reads_command->execute_with_bsub(test => 1), 'execute_with_bsub genome-model add-reads process-low-quality=alignments maq');



##NOTES-------------
##we should probably sync database after each command to confirm any entered values are valid...and print a meaningful error message if this fails
##this should probably be a addreads.maq test since we are hardcoding subcommands?
##this is only the front half right now.
## I desire cookies...please bring cookies now.





sub get_id {
    return $COUNTER++;
}




