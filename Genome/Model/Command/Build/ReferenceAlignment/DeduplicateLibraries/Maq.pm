package Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries::Maq;

use strict;
use warnings;

use Genome;
use Command;
use File::Basename;
use IO::File;

class Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries::Maq {
    is => ['Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries', 'Genome::Model::Command::MaqSubclasser'],
    has => [ 
          parallel_switch => {
                  is => 'String',
              doc => 'Set to 0 for serial execution.  Set to 1 for parallel execution.',
              default_value => '1',
              is_optional =>1,
           },  
           ],
};

sub help_brief {
    "Use maq to align reads";
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


sub execute {
    my $self = shift;
    my $now = UR::Time->now;
    $DB::single=1;
    $self->parallel_switch(1);
    $self->status_message("Running in PARALLEL.") if ($self->parallel_switch eq '1');
    $self->status_message("Running in SERIAL.") if ($self->parallel_switch ne '1');
  
    $self->status_message("Setting up inputs...");
    
    my @subsequences = grep { $_ ne 'all_sequences' } $self->model->get_subreference_names(reference_extension  => 'bfa');
    
    my $maplist_dir = $self->build->accumulated_alignments_directory;
    #my $log_dir = $self->resolve_log_directory;
    my $log_dir = "/tmp/";
    my $maq_pathname = $self->proper_maq_pathname('genotyper_name');
   
    $self->status_message("Using maq cmd path: ".$maq_pathname);
    $self->status_message("Using maplist directory: ".$maplist_dir);
   
    unless (-e $maplist_dir) { 
        unless ($self->create_directory($maplist_dir)) {
            #doesn't exist can't create it...quit
            $self->error_message("Failed to create directory '$maplist_dir':  $!");
            return;
        }
        chmod 02775, $maplist_dir;
    } else {
        unless (-d $maplist_dir) {
            #does exist, but is a file, not a directory? quit.
            $self->error_message("File already exists for directory '$maplist_dir':  $!");
            return;
        }
    }

    my @read_sets = $self->model->instrument_data_assignments;
    my %library_alignments;
    my $count = 0;
    #accumulate the readsets per library
    for my $read_set_link (@read_sets) {
        #$self->status_message("Read set: \n".$read_set_link->short_name .", ". $read_set_link->sample_name.", ".$read_set_link->full_path ) if ($count eq 1);
        my $library = $read_set_link->library_name;
        #$self->status_message("Original Library: ".$library);
        my @read_set_maps = $read_set_link->alignment_file_paths;
        #$self->status_message("library $library alignment file paths: \n".join("\n",@read_set_maps) ) if ($count eq 1);
        push @{$library_alignments{$library}}, @read_set_maps;
    }

    $self->status_message("About to call Dedup. Input params are... \n");
    #$self->status_message("Libraries and readsets: \n");
    #prepare the input for parallelization
    my @list_of_library_alignments;
    for my $library_key ( keys %library_alignments ) {
	my @read_set_list = @{$library_alignments{$library_key}};	
        $self->status_message("Library: ".$library_key." Read sets count: ". scalar(@read_set_list) ."\n");
        my %library_alignments_item = ( $library_key => \@read_set_list );  
        push @list_of_library_alignments, \%library_alignments_item; 
        $count = $count + 1;
    }  

    
    $self->status_message("Libraries added: ".$count ); 

    $self->status_message("Size of library alignments: ".@list_of_library_alignments ); 
    #checking outbound list
    for my $list_item (@list_of_library_alignments) {
        my %hash = %{$list_item};
        for my $hash_item (keys %hash) {
		my @test_list = @{$hash{$hash_item}};
    		$self->status_message("Checking library and size: ".$hash_item.",".scalar(@test_list));
	}
    } 

    $self->status_message("Accumulated Alignments Dir: ".$maplist_dir);
    $self->status_message("Subref names: ".join (",", @subsequences) );
    $self->status_message("Size of library alignments: ".@list_of_library_alignments ); 
    $self->status_message("Aligner: ". $self->model->read_aligner_name ); 

#parallelization starts here
    if ( $self->parallel_switch eq "1" ) {
	require Workflow::Simple;
        $Workflow::Simple::store_db=0;
        
	my $op = Workflow::Operation->create(
            name => 'Deduplicate libraries.',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries::Dedup')
        );

	$op->parallel_by('library_alignments');

        my $output = Workflow::Simple::run_workflow_lsf(
            $op,
            'accumulated_alignments_dir' =>$maplist_dir, 
            'library_alignments' =>\@list_of_library_alignments,
            'subreference_names' =>\@subsequences, 
            'maq_cmd' =>$maq_pathname,
            'aligner' => $self->model->read_aligner_name,
            'mapsplit_cmd' => $self->proper_mapsplit_pathname('read_aligner_name'),
             
        );
 
        $self->status_message("Output: ".$output);

    } else {

    	my $rmdup = Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries::Dedup->create(
                    accumulated_alignments_dir =>$maplist_dir, 
                    library_alignments =>\@list_of_library_alignments,
                    subreference_names =>\@subsequences, 
                    maq_cmd =>$maq_pathname,
                    aligner => $self->model->read_aligner_name,
                    mapsplit_cmd => $self->proper_mapsplit_pathname('read_aligner_name'),
                  );
       
	#$self->_trap_messages($rmdup);
	#execute the tool
	
	$rmdup->execute;

   }

   #starting mixed map merge of all maps 
   $now = UR::Time->now;
   $self->status_message(">>> Beginning mapmerge at $now .");
   my $out_filepath= $maplist_dir . "/mixed_library_submaps/";

   unless (-e $out_filepath) { 
        unless ($self->create_directory($out_filepath)) {
            #doesn't exist can't create it...quit
            $self->error_message("Failed to create directory '$out_filepath':  $!");
            return;
        }
        chmod 02775, $out_filepath;
    } else {
        unless (-d $maplist_dir) {
            #does exist, but is a file, not a directory? quit.
            $self->error_message("File already exists for directory '$out_filepath':  $!");
            return;
        }
    }


   if ( scalar <$out_filepath/*> ) { 
  	$self->status_message("Directory $out_filepath is not empty.  Not executing mapmerge.  Remove directory contents and rerun to generate mixed maps.");
   } else { 

   	my @libraries =  keys %library_alignments; 
   	$self->status_message("Libraries: ".join(",",@libraries));
   	$self->status_message("Maps: ".join(",",@subsequences));
        my @merge_commands;
        push @subsequences, "other";	
 	for my $sub_map (@subsequences) {
        	my @maps_to_merge;
        	for my $library_submap (@libraries) {
			push @maps_to_merge, $maplist_dir."/".$library_submap."/".$sub_map.".map";	
        	} 
        	$now = UR::Time->now;
      		my $cmd ="$maq_pathname mapmerge $out_filepath$sub_map.map ".join(" ",@maps_to_merge);
                push (@merge_commands, $cmd);
    		$self->status_message("Creating string: $cmd at $now.");
       		#my $rv = system($cmd);
   		#if($rv) {
       		#	$self->error_message("problem running $cmd");
       		#	return;
    		#}
   	}

        #running commands
	my $log_path = $log_dir."/rmdup/";
        if ( $self->parallel_switch eq '1' ) {
		my $pcrunner = Genome::Model::Tools::ParallelCommandRunner->create(command_list=>\@merge_commands,log_path=>$log_path);
        	$pcrunner->execute;
        } else {
                for my $merge_cmd (@merge_commands) {
        	        $now = UR::Time->now;
    		        $self->status_message("Executing $merge_cmd at $now.");
                	my $rv = system($merge_cmd);
   			if($rv) {
       				$self->error_message("problem running $merge_cmd");
       				return;
    			}
		}
        }
       


  }

  $now = UR::Time->now;
  $self->status_message("<<< Completed mapmerge at $now .");
  $self->status_message("*** All processes completed. ***");
  #my @status_messages = $rmdup->status_messages();
  #$self->status_message("Messages: ".join("\n",@status_messages) );

return 1;

}

sub _trap_messages {
    my $self = shift;
    my $obj = shift;

    $obj->dump_error_messages($self->{_messages});
    $obj->dump_warning_messages($self->{_messages});
    $obj->dump_status_messages($self->{_messages});
    $obj->queue_error_messages(0);
    $obj->queue_warning_messages(0);
    $obj->queue_status_messages(0);
}

sub verify_successful_completion {
	return 1;
}


1;
