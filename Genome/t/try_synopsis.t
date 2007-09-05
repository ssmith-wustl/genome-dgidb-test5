#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 5;

use above "Genome";
use Genome::Model::Command::Create;


sub get_example_from_synopsis {
    my $command_name = shift;
    
    my $cmd = $command_name->help_synopsis();
    $cmd =~ s/\n//g;
    $cmd =~ s/\s+/ /g;
    $cmd =~ s/genome-model //;
    #print $cmd;
    ok($cmd, "got a command from the synopsis");
    
    my ($name) = ($cmd =~ /\-\-name\s+(\S+)/);
    ok($name, "got name $name from the command");
    
    my @cmd = split(/\s+/,$cmd);
    
    return ($name, @cmd);
}

# create

my ($model_name, @command_argv) = get_example_from_synopsis("Genome::Model::Command::Create");

my @before = Genome::Model->get(name => $model_name);
is(scalar(@before), 0, "model does NOT exist before test");

my $exit_code = Genome::Model::Command->_execute_with_shell_params_and_return_exit_code(@command_argv);
is($exit_code,0,"execution worked of @command_argv");

my @after = Genome::Model->get(name => $model_name);
is(scalar(@after), 1, "model DOES exist after test");    

exit if $exit_code;

my $model = $after[0];

# add reads

my ($model_name, @command_argv) = get_example_from_synopsis("Genome::Model::Command::AddReads");

$DB::single = 1;
my @before = $model->run_chunk_list;
is(scalar(@before), 0, "has no run chunks before test");

my $exit_code = Genome::Model::Command->_execute_with_shell_params_and_return_exit_code(@command_argv, "test", 1);
is($exit_code,0,"execution worked of @command_argv");

my @after = $model->run_chunks;
is(scalar(@after), 1, "has run chunks after test");    

exit if $exit_code;


