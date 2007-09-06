#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 8;

use above "Genome";
use Genome::Model::Command::Create;


sub get_example_from_synopsis {
    my $command_name = shift;
    my @param_names = @_;
    
    my $cmd = $command_name->help_synopsis();
    $cmd =~ s/\n//g;
    $cmd =~ s/\s+/ /g;
    $cmd =~ s/genome-model //;
    ok($cmd, "got a command from the synopsis of $command_name");
    exit 1 unless $cmd;
    
    my @cmd = split(/\s+/,$cmd);
    
    my @extra_values;
    for my $param_name (@param_names) {
        my ($value) = ($cmd =~ /\-\-$param_names[0]\s+(\S+)/);
        ok($value, "got $param_names[0] $value from the command");
        push @extra_values, $value;
    }
    
    return (\@cmd,@extra_values);
}

sub test_command {
    my $class;
    
    my ($command_argv) = get_example_from_synopsis("Genome::Model::Command::AddReads::AlignReads");
    my $exit_code = Genome::Model::Command->_execute_with_shell_params_and_return_exit_code(@$command_argv, "test", 1);
    is($exit_code,0,"execution worked of genome-model @$command_argv");
    
    exit if $exit_code;
}

my $command_argv;
my $exit_code;

# create
my $model = test_create_model();

# add reads
test_assign_run();

# align reads
test_command("Genome::Model::Command::AddReads::AlignReads");

# identify variations
test_command("Genome::Model::Command::AddReads::IdentifyVariations");

# update genotype probabilities
test_command("Genome::Model::Command::AddReads::AlignReads");


sub test_create_model {
    my $model_name;
    ($command_argv,$model_name) = get_example_from_synopsis("Genome::Model::Command::Create","name");

    my @before = Genome::Model->get(name => $model_name);
    is(scalar(@before), 0, "model does NOT exist before test");
    
    $exit_code = Genome::Model::Command->_execute_with_shell_params_and_return_exit_code(@$command_argv);
    is($exit_code,0,"execution worked of genome-model @$command_argv");
    
    my @after = Genome::Model->get(name => $model_name);
    is(scalar(@after), 1, "model DOES exist after test");    
    
    exit if $exit_code;
    
    my $model = $after[0];
    
    return $model;
    
}

sub test_assign_run {
    
    my ($command_argv) = get_example_from_synopsis("Genome::Model::Command::AddReads::AssignRun");
    #my @before = $model->run_chunk_list;
    #is(scalar(@before), 0, "has no run chunks before test");
    $exit_code = Genome::Model::Command->_execute_with_shell_params_and_return_exit_code(@$command_argv, "test", 1);
    is($exit_code,0,"execution worked of genome-model @$command_argv");
    #my @after = $model->run_chunks;
    #is(scalar(@after), 1, "has run chunks after test");
    
}
