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
              default_value => '0',
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
    $self->parallel_switch(0);
    $self->status_message("Running in PARALLEL.") if ($self->parallel_switch eq '1');
    $self->status_message("Running in SERIAL.") if ($self->parallel_switch ne '1');
  
    $self->status_message("Setting up inputs...");
    
    my @subsequences = grep { $_ ne 'all_sequences' } $self->model->get_subreference_names(reference_extension  => 'bfa');
    
    my $maplist_dir = $self->build->accumulated_alignments_directory;
    #my $log_dir = $self->resolve_log_directory;
    my $log_dir = "/tmp/";

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

   my @idas = $self->model->instrument_data_assignments;
    my %library_alignments;
    my $count = 0;
    #accumulate the readsets per library
    for my $ida (@idas) {
        #$self->status_message("Read set: \n".$read_set_link->short_name .", ". $read_set_link->sample_name.", ".$read_set_link->full_path ) if ($count eq 1);
        my $library = $ida->library_name;
        my $alignment = $ida->alignment;
        #$self->status_message("Original Library: ".$library);
        my @read_set_maps = $alignment->alignment_file_paths;
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
            'aligner_version' => $self->model->read_aligner_version,
        );
 
        $self->status_message("Output: ".$output);

    } else {

    	my $rmdup = Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries::Dedup->create(
                    accumulated_alignments_dir => $maplist_dir, 
                    library_alignments =>\@list_of_library_alignments,
                    subreference_names =>\@subsequences,
                    aligner_version => $self->model->read_aligner_version,
                  );
       
	#execute the tool
	
	$rmdup->execute;

   }
 
   #merge those Bam files...BAM!!!
   $now = UR::Time->now;
   $self->status_message(">>> Beginning Bam merge at $now.");
   my $bam_merge_tool = "/gscuser/dlarson/src/samtools/tags/samtools-0.1.2/samtools merge";
   my $bam_index_tool = "/gscuser/dlarson/src/samtools/tags/samtools-0.1.2/samtools index";
   my $bam_merged_output_file = $maplist_dir."/".$self->model->subject_name."_merged_rmdup.bam";
   my $bam_non_merged_output_file = $maplist_dir."/".$self->model->subject_name."_rmdup.bam";
   my $bam_final;

 
   if (-s $bam_merged_output_file )  {
   	$self->error_message("The bam file: $bam_merged_output_file already exists.  Skipping bam processing.  Please remove this file and rerun to generate new bam files.");
   } if (-s $bam_non_merged_output_file )  {
   	$self->error_message("The bam file: $bam_non_merged_output_file already exists.  Skipping bam processing.  Please remove this file and rerun to generate new bam files.");
   }  else {
 
   	   #get the bam files from the alignments directory
   	   my @bam_files = <$maplist_dir/*.bam>;

	   #remove previously merged/rmdup bam files from the list of files to merge... 
	   my $i=0;
	   for my $each_bam (@bam_files) {
		#if the bam file name contains the string '_rmdup.bam', remove it from the list of files to merge
		my $substring_index = index($each_bam, "_rmdup.bam");
		unless ($substring_index == -1) {
			$self->status_message($bam_files[$i]. " will not be merged.");
			delete $bam_files[$i];
		}		
		$i++;
	   }

	   if (scalar(@bam_files) == 0 ) {
		$self->error_message("No bam files have been found at: $maplist_dir");
	   } elsif (scalar(@bam_files) == 1) {
		my $single_file = shift(@bam_files);
		$self->status_message("Only one bam file has been found at: $maplist_dir. Not merging, only renaming.");
		my $rename_cmd = "mv ".$single_file." ".$bam_non_merged_output_file;
		$self->status_message("Bam rename commmand: $rename_cmd");
		my $bam_rename_rv = system($rename_cmd);
		unless ($bam_rename_rv==0) {
			$self->error_message("Bam file rename error!  Return value: $bam_rename_rv");
		} else {
			#renaming success
			$bam_final = $bam_non_merged_output_file; 
		} 
	   } else {
		$self->status_message("Multiple Bam files found.  Bam files to merge: ".join(",",@bam_files) );
		my $bam_merge_cmd = "$bam_merge_tool $bam_merged_output_file ".join(" ",@bam_files); 
		$self->status_message("Bam merge command: $bam_merge_cmd");
		my $bam_merge_rv = system($bam_merge_cmd);
		$self->status_message("Bam merge return value: $bam_merge_rv");
		unless ($bam_merge_rv == 0) {
			$self->error_message("Bam merge error!  Return value: $bam_merge_rv");
		} else {
			#merging success
			$bam_final = $bam_merged_output_file;
		}
	   }

	   my $bam_index_rv;
	   if (defined $bam_final) {
		$self->status_message("Indexing bam file: $bam_final");
		my $bam_index_cmd = $bam_index_tool ." ". $bam_final;
		$bam_index_rv = system($bam_index_cmd);
		unless ($bam_index_rv == 0) {
			$self->error_message("Bam index error!  Return value: $bam_index_rv");
		} else {
			#indexing success
			$self->status_message("Bam indexed successfully.");
		}
	   }  else {
		#no final file defined, something went wrong	
		$self->error_message("Bam index error!  Return value: $bam_index_rv");
	   }

	   $now = UR::Time->now;
	   $self->status_message("<<< Completing Bam merge at $now.");

	   #remove intermediate files
	   $now = UR::Time->now;
	   $self->status_message(">>> Removing intermediate files at $now");
	   
	   #remove the library bam files and indicies
	  
	   #remove maps 
	   my $glob_expr = $maplist_dir."/*.map";
	   my @lib_map_files = glob($glob_expr);
	  
	   for my $each_lib_map_file (@lib_map_files) {
		my $rm_map_cmd = "unlink $each_lib_map_file";
		$self->status_message("Executing remove command: $rm_map_cmd");
		my $rm_map_rv = system("$rm_map_cmd");
		unless ($rm_map_rv == 0) {
			$self->error_message("There was a problem with the map remove command: $rm_map_rv");
		} 
	   } 
	   
	   #remove bam files 
	   for my $each_bam_file (@bam_files) {
		my $rm_cmd = "unlink $each_bam_file";
		$self->status_message("Executing remove command: $rm_cmd");
		my $rm_rv1 = system("$rm_cmd");
		my $rm_rv2 = system("$rm_cmd".".bai"); #remove each index as well
		unless ($rm_rv1 == 0) {
			$self->error_message("There was a problem with the bam remove command: $rm_rv1");
		}  
		unless ($rm_rv2 == 0) {
			$self->error_message("There was a problem with the bam index remove command: $rm_rv2");
		}
	   } 

      } #end else for skipping Bam process

   $now = UR::Time->now;
   $self->status_message("<<< Completed removing intermediate files at $now");

   #######################################
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
                    my $library_sub_map_file = $maplist_dir .'/'. $library_submap .'/'. $sub_map .'.map';
                    if (-e $library_sub_map_file) {
			push @maps_to_merge, $library_sub_map_file;
                    }
        	}
                if (@maps_to_merge) {
                    $now = UR::Time->now;
                    my $maq_pathname = $self->proper_maq_pathname('read_aligner_version');
                    my $cmd ="$maq_pathname mapmerge $out_filepath$sub_map.map ".join(" ",@maps_to_merge);
                    push (@merge_commands, $cmd);
                    $self->status_message("Creating string: $cmd at $now.");
                    #my $rv = system($cmd);
                    #if($rv) {
                    #	$self->error_message("problem running $cmd");
                    #	return;
                    #}
                }
   	}

        #running commands
	my $log_path = $log_dir."/rmdup/";
        if ( $self->parallel_switch eq '1' ) {
		my $pcrunner = Genome::Model::Tools::ParallelCommandRunner->create(command_list=>\@merge_commands,log_path=>$log_path);
        	$pcrunner->execute;
                #TODO: check return value or result of parallel command runner
        } else {
                for my $merge_cmd (@merge_commands) {
        	        $now = UR::Time->now;
    		        $self->status_message("Executing $merge_cmd at $now.");
                	my $rv = system($merge_cmd);
   			if($rv) {
                            $self->error_message("non-zero return value($rv) from command: $merge_cmd");
                            die($self->error_message);
    			}
		}
        }
  }

  $now = UR::Time->now;
  $self->status_message("<<< Completed mapmerge at $now .");
  $self->status_message("*** All processes completed. ***");
  #my @status_messages = $rmdup->status_messages();
  #$self->status_message("Messages: ".join("\n",@status_messages) );

#return verify_successful_completion();
return 1;

}


sub verify_successful_completion {

    my $self = shift;

    my $return_value = 1;
    my $build = $self->build;

    if ( defined($build) ) {
	    my $maplist_dir = $self->build->accumulated_alignments_directory;
	    my $mixed_library_dir = $maplist_dir."/mixed_library_submaps";

	    unless (-d $mixed_library_dir) {
		$self->error_message("Can't verify successful completeion of Deduplication step.  Mixed library submap directory does not exist:  $mixed_library_dir");	  	
		return 0;
	    } else {
		my @submap_files = glob("$maplist_dir/mixed_library_submaps");
		unless ( scalar(@submap_files) > 0 ) { 
			$self->error_message("Can't verify successful completion of Deduplication step.  There should be at least 1 submap in the $maplist_dir/mixed_library_submaps directory.");	  	
			$self->error_message("$maplist_dir/mixed_library_submaps directory contents:");
			return 0; 
		}
	    }
    } else {
	$self->error_message("Can't verify successful completion of Deduplication step. Build is undefined.");
   	return 0;	
    }
    return $return_value;
}


1;
