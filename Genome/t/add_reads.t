#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 52;

use above "Genome";
#use Genome::Model::Command::AddReads;

my $model = Genome::Model->create(name => 'test',
                                  dna_type => 'test',
                                  genotyper_name => 'Maq',
                                  read_aligner_name => 'Maq',
                                  reference_sequence_name => 'foo',
                                  sample_name => 'test');
ok($model, "Create a Genome::Model for testing");

my $files_path = "/tmp/add_reads_test_$$";

{ 
    # Set up a test pipeline without bsubbing
    # Note: using test=>1 means the sub-sub commands (like G::M::C::AssignRun::Solexa)
    # don't get created, only sub commands (like G::M::C::AssignRun)
    my $command = Genome::Model::Command::AddReads->create(model_id => $model->id,
                                                           sequencing_platform => 'Solexa',
                                                           full_path => $files_path,
                                                           test => 1,
                                                           bsub => 0,
                                                          );
    ok($command, "Created an AddReads command object");
    
    ok($command->execute(), "AddReads executed");
    
    
    # That should have created a RunChunk record
    my @runs = Genome::RunChunk->get(sequencing_platform => 'Solexa',
                                     full_path => $files_path);
    is(scalar(@runs), 8, "8 Genome::RunChunk objects were created, one for each lane");
    
    
    # Check the properties of all the command objects created by AddReads
    my @sub_commands = grep { $_->can('model_id') && $_->model_id == $model->id } Command->get();
    my $number_of_sub_commands_created = 33;  # one add-reads, and 8 of all the sub-steps
    is(scalar(@sub_commands), $number_of_sub_commands_created, "$number_of_sub_commands_created command objects were created");
    
    foreach my $command_class (qw( Genome::Model::Command::AddReads
                                   Genome::Model::Command::AddReads::AssignRun
                                   Genome::Model::Command::AddReads::AlignReads
                                   Genome::Model::Command::AddReads::UpdateGenotypeProbabilities
                                   Genome::Model::Command::AddReads::IdentifyVariations
                               )) {
        ok((grep {$_->get_class_object->class_name eq $command_class} @sub_commands), "Command $command_class exists");
    }

    # When the sub-commands automaticly subclass themselves as the correct
    # sub-sub command, then uncomment the below block to check that the 
    # parameters of them are correct
    #foreach my $command ( @sub_commands ) {
    #    my $class_name = $command->get_class_object->class_name;
    #    is($command->run_id, $run->id, "$class_name has the correct run-id");
    #    is($command->model_id, $model->id, "$class_name has the correct model-id");
    #
    #    # Check the event-like properties
    #    ok( $command->date_scheduled, "$class_name has a date_scheduled");
    #    ok( $command->date_completed, "$class_name has a date_completed");
    #    is( $command->event_status , 'Succeeded', "$class_name succeeded");
    #    is( $command->event_type, $command->command_name, "$class_name has the correct event_type");
    #    is( $command->lsf_job_id, undef, "lsf_job_id is correctly empty");
    #}

    # Clean up...
    $_->delete foreach (@sub_commands);
    $_->delete foreach (@runs);
}


# This variable hold the name of the command that would run on the blades 
our $bsubbed_command = 'genome-model-bsub';
$Genome::Model::Command::AddReads::GENOME_MODEL_BSUBBED_COMMAND = $bsubbed_command;

my %bsub_command_line_results = (
    'Genome::Model::Command::AddReads' => undef,
    'Genome::Model::Command::AddReads::AssignRun' =>
              'bsub -q long  %s add-reads assign-run --run-id %d --model-id %d', 

    'Genome::Model::Command::AddReads::AlignReads' =>
              'bsub -q long  -w test %s add-reads align-reads --run-id %d --model-id %d',

    'Genome::Model::Command::AddReads::UpdateGenotypeProbabilities' =>
              'bsub -q long  -w test %s add-reads update-genotype-probabilities --run-id %d --model-id %d',

    'Genome::Model::Command::AddReads::IdentifyVariations' =>
              'bsub -q long  -w test %s add-reads identify-variations --run-id %d --model-id %d',
);

{
    # Try again with bsub on
    my $command = Genome::Model::Command::AddReads->create(model_id => $model->id,
                                                           sequencing_platform => 'Solexa',
                                                           full_path => $files_path,
                                                           test => 1,
                                                           bsub => 1,
                                                        );
    ok($command, "Created an AddReads command object with bsub");
    
    ok($command->execute(), "AddReads executed");

    # That should have created a RunChunk record
    my @runs = Genome::RunChunk->get(sequencing_platform => 'Solexa',
                                     full_path => $files_path);
    is(scalar(@runs), 8, "8 Genome::RunChunk objects were created, one for each lane");


    # Check the properties of all the command objects created by AddReads
    my @sub_commands = grep { $_->can('model_id') && $_->model_id == $model->id } Command->get();
    my $number_of_sub_commands_created = 33;
    is(scalar(@sub_commands), $number_of_sub_commands_created, "$number_of_sub_commands_created command objects were created");

    foreach my $command_class (qw( Genome::Model::Command::AddReads
                                   Genome::Model::Command::AddReads::AssignRun
                                   Genome::Model::Command::AddReads::AlignReads
                                   Genome::Model::Command::AddReads::UpdateGenotypeProbabilities
                                   Genome::Model::Command::AddReads::IdentifyVariations
                               )) {
        ok((grep {$_->get_class_object->class_name eq $command_class} @sub_commands), "Command $command_class exists");
    }

    # When the sub-commands automaticly subclass themselves as the correct
    # sub-sub command, then uncomment the below block to check that the 
    # parameters of them are correct
    foreach my $command ( @sub_commands ) {
        my $class_name = $command->get_class_object->class_name;
        #is($command->run_id, $run->id, "$class_name has the correct run-id");
        #is($command->model_id, $model->id, "$class_name has the correct model-id");

        my $status_message = $command->status_message();
        $status_message ||= '';  # Converts an undef (from AddReads) to empty string
        $status_message =~ s/^Test mode, command not executed: //;
        
        my $expected_message = $bsub_command_line_results{$class_name} || '';
my $run=1;
        $expected_message = sprintf($expected_message, $bsubbed_command, $command->run_id, $model->id) if ($expected_message);
        is ($status_message,
            $expected_message,
            "$class_name would have run the right bsub command");

        # Check the event-like properties
        #ok( $command->date_scheduled, "$class_name has a date_scheduled");
        #ok( $command->date_completed, "$class_name has a date_completed");
        #is( $command->event_status , 'Succeeded', "$class_name succeeded");
        #is( $command->event_type, $command->command_name, "$class_name has the correct event_type");
        #is( $command->lsf_job_id, undef, "lsf_job_id is correctly empty");
    }

    # Clean up...
    $_->delete foreach (@sub_commands);
    $_->delete foreach (@runs);
}



