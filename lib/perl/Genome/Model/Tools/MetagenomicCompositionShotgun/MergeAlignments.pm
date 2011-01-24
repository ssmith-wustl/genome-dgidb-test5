package Genome::Model::Tools::MetagenomicCompositionShotgun::MergeAlignments;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::MetagenomicCompositionShotgun::MergeAlignments {
    is  => ['Command'],
    has => [
        working_directory => {
            is  => 'ARRAY',
            is_input => '1',
            doc => 'The working directory.',
        },
        alignment_files => {
            is  => 'ARRAY',
            is_input => '1',
            doc => 'The reads to align.',
        },
        unaligned_files => {
        	is  => 'ARRAY',
            is_input => '1',
            doc => 'The unaligned files.',
        },
        merged_aligned_file => {
            is  => 'String',
            is_output => '1',
            is_optional => '1',
            doc => 'The resulting alignment.',
        },
         _working_directory => {
        	is  => 'String',
            is_optional => '1',
            doc => 'The resulting alignment.',
        },
        lsf_resource => {
                is_param => 1,
                value => "-R 'select[mem>8000 && model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=8000]' -M 8000000",
        },
    ],
};

sub help_brief {
    'Align reads against a given metagenomic reference.';
}

sub help_detail {
    return <<EOS
    Align reads against a given metagenomic reference.
EOS
}

sub execute {
    my $self = shift;

    $self->dump_status_messages(1);
    $self->status_message(">>>Running MergeAlignments at ".UR::Time->now);
    #my $model_id = $self->model_id;
    my $alignment_files_ref = $self->alignment_files;
    my @alignment_files = @$alignment_files_ref;
    
    my $unaligned_files_ref = $self->unaligned_files;
    my @unaligned_files = @$unaligned_files_ref;
    
    #get parallelized inputs 
    #all of the alignment jobs are sending in the same working directory.  
    #pick the first one
    my $working_directory_ref = $self->working_directory;
    my @working_directory_list = @$working_directory_ref;
    my $working_directory = $working_directory_list[0];
    $self->_working_directory($working_directory);
    
    #my $working_directory = $self->working_directory."/alignments/";
    $self->status_message("Working directory: ".$working_directory);
    
    #first cat the unaligned reads, then the aligned files
    my $unaligned_combined = $working_directory."/unaligned_merged.sam";
    my $merged_alignment_unsorted = $working_directory."/aligned_merged_unsorted.sam";
    my @expected_output_files = ( $unaligned_combined, $merged_alignment_unsorted );
    my $rv_check = Genome::Sys->are_files_ok(input_files=>\@expected_output_files);
    #my $rv_unaligned_check = Genome::Sys->is_file_ok($unaligned_combined);
    if ($rv_check) {
    	$self->status_message("Output files exists.  Skipping the generation of the unaligned reads files and aligned merged unsorted file.  If you would like to regenerate these files, remove them and rerun.");  	
    } else {
        
    	my $rv_cat = Genome::Sys->cat(input_files=>\@unaligned_files,output_file=>"$unaligned_combined.cat");
    	if ($rv_cat) {
    		Genome::Sys->mark_file_ok("$unaligned_combined.cat");
    	} else {
    		$self->error_message("There was a problem generating the combined unaligned file: $unaligned_combined.cat");
            return;
    	}

        my $unaligned_1 = $unaligned_files[0];
        my $unaligned_1_sorted = $unaligned_1.".sorted";
        my $unaligned_2 = $unaligned_files[1];
        my $unaligned_2_sorted = $unaligned_2.".sorted";
        
        my $sort_1_rv = Genome::Sys->shellcmd(
            cmd => "sort $unaligned_1 > $unaligned_1_sorted",
            input_files => [$unaligned_1],
            output_files => [$unaligned_1_sorted],
        );

        unless ($sort_1_rv){
            $self->error_message("Failed to sort unaligned file $unaligned_1");
            return;
        }
        
        my $sort_2_rv = Genome::Sys->shellcmd(
            cmd => "sort $unaligned_2 > $unaligned_2_sorted",
            input_files => [$unaligned_2],
            output_files => [$unaligned_2_sorted],
        );
        
        unless ($sort_2_rv){
            $self->error_message("Failed to sort unaligned file $unaligned_1");
            return;
        }

        my $unaligned_ofh;
        if (Genome::Sys->validate_file_for_writing($unaligned_combined)){
            $unaligned_ofh = IO::File->new(">$unaligned_combined");
        }else{
            print "ERROR\n";   
        }
        my $unaligned_fh_1 = Genome::Sys->open_file_for_reading($unaligned_1_sorted);
        my $unaligned_fh_2 = Genome::Sys->open_file_for_reading($unaligned_2_sorted);
        my @last_set;
        my $last_read_name;
        @last_set = ($unaligned_fh_2->getline, $unaligned_fh_2->getline);
        ($last_read_name) = split(/\t/, $last_set[0]);

        while ($_ = $unaligned_fh_1->getline and defined $_ and defined $last_read_name){
            my $line = $_;
            my $line_pair = $unaligned_fh_1->getline;
            my ($read_name) = split(/\t/, $line);
            while (defined $last_read_name and $last_read_name lt $read_name){
                @last_set = ($unaligned_fh_2->getline, $unaligned_fh_2->getline);
                if (defined $last_set[0]){
                    ($last_read_name) = split(/\t/, $last_set[0]);
                }else{
                    $last_read_name = undef;
                }
            }
            if (defined $last_read_name  and $last_read_name eq $read_name){
                $unaligned_ofh->print($line);
                $unaligned_ofh->print($line_pair);
            }
        }
        #finish out file handle 2 after
        while ($_ = $unaligned_fh_1->getline and defined $_){
            $unaligned_ofh->print($_);
        }
    
        $unaligned_ofh->close;
        Genome::Sys->mark_file_ok($unaligned_combined);
        
        if (scalar(@alignment_files) < 2) {
            $self->error_message("*** Invalid number of files to merge: ".scalar(@alignment_files).". Must have 2 or more.  Quitting.");
            return;
        } else {
            my $rv_merge = Genome::Sys->cat(input_files=>\@alignment_files,output_file=>$merged_alignment_unsorted);
            if ($rv_merge != 1) {
                $self->error_message("<<<Failed MergeAlignments on cat merge.  Return value: $rv_merge");
                return;
            }
            $self->status_message("Merge complete.");
            Genome::Sys->mark_file_ok($merged_alignment_unsorted);
        }

    }

    #sort alignment file 


    my $merged_alignment_sorted = $working_directory."/aligned_merged_sorted.sam";

    my @expected_sorted_output_files = ( $merged_alignment_sorted );
    $self->status_message("Starting sort step.  Checking on existence of $merged_alignment_sorted.");
    my $rv_sort_check = Genome::Sys->are_files_ok(input_files=>\@expected_sorted_output_files);

    if ($rv_sort_check == 1) {
        #shortcut this step, all the required files exist.  Quit.
        $self->merged_aligned_file($merged_alignment_sorted);
        $self->status_message("Skipping this step.  If you would like to regenerate these files, remove them and rerun.");
        $self->status_message("<<<Completed MergeAlignments at ".UR::Time->now);
        return 1;
    } else {

        my $tmp_dir = File::Temp::tempdir( DIR => $working_directory, CLEANUP => 1 );
        #sort
        #the 7G = 7Gigs of memory before writing to disk
        my $cmd_sorter = "sort -k 1 -T $tmp_dir -S 7G -o $merged_alignment_sorted $merged_alignment_unsorted";
        my $rv_sort = Genome::Sys->shellcmd(cmd=>$cmd_sorter);											 
        if ($rv_sort != 1) {
            $self->error_message("Sort failed.  Return value: $rv_sort");
            return;
        } else {
            $self->status_message("Sort complete.");
            unless (unlink $merged_alignment_unsorted){
                $self->warning_message("Failed to remove unsorted merged alignment file ". $merged_alignment_unsorted);
            }
            Genome::Sys->mark_files_ok(input_files=>\@expected_sorted_output_files);
            $self->merged_aligned_file($merged_alignment_sorted);
            $self->status_message("<<<Completed MergeAlignments for testing at at ".UR::Time->now);
            return 1;
        }
    }    

    return; 
}

sub resolve_name_sorted_file_name {
    my $self = shift;
    my $refseq_name = shift;
    my $extension = shift;
    return $self->_working_directory."/".$refseq_name."_name_sorted.".$extension;
}

1;
