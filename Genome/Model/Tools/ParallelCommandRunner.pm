package Genome::Model::Tools::ParallelCommandRunner;

use strict;
use warnings;

use Genome;
use Command;
use File::Basename;
use IO::File;
use Genome::Utility::FileSystem;

class Genome::Model::Tools::ParallelCommandRunner {
    is => ['Command'],
    has => [ 
            command_list => { is => 'Array', doc => 'Required List of commands to execute in parallel.' }, 
            log_path => { is => 'String', doc => 'Required path to write log files.' }, 
            log_file => { is => 'String', doc => 'Optional file target to write logs. If provided, all parallel processes will write to this file. If none is provided,each process will write to their own individual log file specified by "[log_path]/parallel_[timestamp].log"', is_optional=>1}, 
           ],
};

sub help_brief {
    "Use workflow to run commands in parallel.";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads postprocess-alignments merge-alignments maq --model-id 5 --ref-seq-id all_sequences
EOS
}

sub help_detail {
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub create {
    my $self = shift->SUPER::create(@_);
    
    return $self;
}

sub execute {
    	my $self = shift;
        my @commands = @{$self->command_list}; 
        #print("Running commands: ".join(",",@commands)."\n");
        print('There are '.scalar(@commands).' to run.');
    
        Genome::Utility::FileSystem->create_directory($self->log_path);
        unless (-d $self->log_path) {
	   print("Can't create directory for logging: ".$self->log_path);
	   $self->error_message("Can't create directory for logging: ".$self->log_path);
           die();
        }

	require Workflow::Simple;
        $Workflow::Simple::store_db=0;
        
	my $op = Workflow::Operation->create(
            name => 'Parallel Command.',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::ParallelCommand')
        );

	$op->parallel_by('command_list');

        my $output = Workflow::Simple::run_workflow_lsf(
            $op,
            'command_list' =>\@commands, 
            'log_file' =>$self->log_file, 
            'log_path' =>$self->log_path, 
        );
 
        #$self->status_message("Output: ".$output);
        #print("Output: ".$output);

        while ( my ($key, $value) = each(%$output) ) {
                if ( $key eq 'result' ) {	
                	#print "Output key: $key \n";
			my @result_array = @{$value};
                	for my $result_item (@result_array) {
                    		print "Result: $result_item";
                	}
        	}
	} 


	#try printing the output
	#for my $output_item (keys %output) {
        #        my $output_string = $output{$output_item};
        #        $self->status_message("Output key: $output_string, Output value: $output_string");
        #        print("Output key: $output_string, Output value: $output_string");
        #}

return 1;

}


1;
