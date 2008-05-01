package Genome::Model::Command::AddReads::AlignReads::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;

class Genome::Model::Command::AddReads::AlignReads::Maq {
    is => ['Genome::Model::Event', 'Genome::Model::Command::MaqSubclasser'], 
    has => [
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
        run_id => { is => 'Integer', is_optional => 0, doc => 'the genome_model_run on which to operate' },
    ],
};

sub help_brief {
    "Use maq to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub bsub_rusage {
    return "-R 'select[type=LINUX64]'";

}

sub should_bsub { 1;}

sub execute {
    my $self = shift;
    
$DB::single = 1;
    my $model = Genome::Model->get(id => $self->model_id);
    my $maq_pathname = $self->proper_maq_pathname('read_aligner_name');

   # ensure the reference sequence exists.
    my $ref_seq_file =  $model->reference_sequence_path . "/all_sequences.bfa";
    
    unless (-e $ref_seq_file) {
        $self->error_message(sprintf("reference sequence file %s does not exist.  please verify this first.", $ref_seq_file));
        return;
    }
    
    my $lane = $self->run->limit_regions;
    unless ($lane) {
        $self->error_message("There is no limit_regions attribute on run_id ".$self->run_id);
        return;
    }

    my $working_dir = $self->resolve_run_directory;

    # Make sure the output directory exists
    unless (-d $working_dir) {
        $self->error_message("working directory $working_dir does not exist, please run assign-run first");
        return;
    }

    # does this model specify to keep or eliminate duplicate reads
    my @passes = ('unique') ;
    if (! $model->multi_read_fragment_strategy or
        $model->multi_read_fragment_strategy ne 'EliminateAllDuplicates') {
        push @passes, 'duplicate';
    }

    # use maq to do the alignments
    my @prior_events_to_wait_on;
    foreach my $pass ( @passes ) {
        # See if we can re-use data from another run, and just symlink to it
        my $prior_event = $self->_check_for_shortcut($pass);
        if ($prior_event) {
            push @prior_events_to_wait_on, $prior_event;
            next;
        }

        # Convert the fastq files into bfq files

        my $fastq_method = sprintf("sorted_%s_fastq_file_for_lane", $pass);
        my $fastq_pathname = $self->$fastq_method;
        unless (-f $fastq_pathname || -z $fastq_pathname ) {
            $self->error_message("fastq file does not exist or has zero size $fastq_pathname");
            return;
        }

        my $bfq_method = sprintf("%s_bfq_file_for_lane", $pass);
        my $bfq_pathname = $self->$bfq_method;
        unless (-f $bfq_pathname) {
            system("$maq_pathname fastq2bfq $fastq_pathname $bfq_pathname");
        }

        # Files needed/creatd by the aligner
        my $aligner_output_method = sprintf("aligner_%s_output_file_for_lane", $pass);
        my $aligner_output = $self->$aligner_output_method;
        # If aligner output file already exists return
        if (-f $aligner_output && -s $aligner_output) {
            $self->error_message("alignner output  file already exist with nonzero size '$aligner_output'");
            return;
        };

        my $reads_method = sprintf("unaligned_%s_reads_file_for_lane", $pass);
        my $reads_file = $self->$reads_method;
        # If reads file already exists return
        if (-f $reads_file && -s $reads_file) {
            $self->error_message("reads file already exist with nonzero size '$reads_file'");
            return;
        };

        my $alignment_file_method = sprintf("%s_alignment_file_for_lane", $pass);
        my $alignment_file = $self->$alignment_file_method();
        # If output file already exists return
        if (-f $alignment_file && -s $alignment_file) {
            $self->error_message("alignment file already exist with nonzero size '$alignment_file'");
            return;
        };

        my $aligner_params = $model->read_aligner_params || '';
        if (-f $self->adaptor_file_for_run()) {
            $aligner_params = join(' ', $aligner_params, '-d', $self->adaptor_file_for_run);
        }

        my $cmdline = sprintf("$maq_pathname map %s -u %s %s %s %s %s > $aligner_output 2>&1",
                              $aligner_params,
                              $reads_file,
                              $alignment_file,
                              $ref_seq_file,
                              $bfq_pathname);

        print "running: $cmdline\n";
        system($cmdline);
        if ($?) {
            my $rv = $? >> 8;
            $self->error_message("got a nonzero exit code ($rv) \$\? ($?) from maq map; something went wrong.  cmdline was $cmdline rv was $rv");
            return;
        }

        # Look through the output file and make sure maq actually finished completely
        unless ($self->_check_maq_successful_completion($aligner_output)) {
            return;
        }

        # use submap if necessary
        my @subsequences = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');

        if (@subsequences) {
            foreach my $seq (@subsequences) {
                my $alignments_dir = $self->alignment_submaps_dir_for_lane;
                unless (-d $alignments_dir ) {
                     mkdir($alignments_dir);
                }
                my $submap_target = sprintf("%s/%s_%s.map",$alignments_dir,$seq,$pass);
                unlink ($submap_target);
              
                # FIXME maq 0.6.4 (and later) have the submap functionality we use removed.  Newer maq's 
                # supposedly have the same file format, so hopefully using maq 0.6.3's submap will do the
                # job for us

                # That last "1" is for the required (because of a bug) 'begin' parameter
                #my $maq_submap_cmdline = "$maq_pathname submap $submap_target $alignment_file $seq 1";
                my $maq_submap_cmdline = "/gsc/pkg/bio/maq/maq-0.6.3_x86_64-linux/maq submap $submap_target $alignment_file $seq 1";
            
                print $maq_submap_cmdline, "\n";
                
                my $rv = system($maq_submap_cmdline);
                if ($rv) {
                     $self->error_message("got a nonzero return value from maq submap; cmdline was $maq_submap_cmdline");
                     return;
                }
            }

            ## Don't need the whole-lane map file anymore
            # Actually, we'll need them in the AcceptReads step, next
            #unlink($alignment_file);
        }  

    } # end foreach unique, duplicate

    # If we were waiting on any other events to finish....
    foreach my $event ( @prior_events_to_wait_on ) {
        my $id = $event->genome_model_event_id;
        my $reloaded = Genome::Model::Event->load(genome_model_event_id => $id);
        my $status = $reloaded->event_status();
        while ($reloaded->event_status eq 'Running') {
            sleep 60;   # Wait a bit until it's done running;
            $reloaded = Genome::Model::Event->load(genome_model_event_id => $id);
        }
        if ($reloaded->event_status ne 'Succeeded') {
            # Since we're dependent on data generated by that one, we fail if they failed
            return;
        }
        
        #Should attempt something like this to avoid circular symlinks
        #if (-l read_link($self->))
    }

    return 1;
}


sub verify_successful_completion {
    my ($self) = @_;

    my $model = Genome::Model->get(id => $self->model_id);
    # does this model specify to keep or eliminate duplicate reads
    my @passes = ('unique') ;
    if (! $model->multi_read_fragment_strategy or
        $model->multi_read_fragment_strategy ne 'EliminateAllDuplicates') {
        push @passes, 'duplicate';
    }
    foreach my $pass ( @passes ) {
        my $aligner_output_method = sprintf("aligner_%s_output_file_for_lane", $pass);
        my $aligner_output = $self->$aligner_output_method;
        unless ($self->_check_maq_successful_completion($aligner_output)) {
            return;
        }
    }
    return 1;
}


sub _check_maq_successful_completion {
    my($self,$output_filename) = @_;

    my $aligner_output_fh = IO::File->new($output_filename);
    unless ($aligner_output_fh) {
        $self->error_message("Can't open aligner output file $output_filename: $!");
        return;
    }

    while(<$aligner_output_fh>) {
        if (m/match_data2mapping/) {
            $aligner_output_fh->close();
            return 1;
        }
    }

    $self->error_message("Didn't find a line matching /match_data2mapping/ in the maq output file '$output_filename'");
    return;
}


# Find other successful executions working on the same data and link to it.
# Returns undef if there is no other data suitable to link to, and we should 
# do it the long way.  Returns 1 if the linking was successful. 0 if we tried
# but there were problems
#
# $type is either 'unique' or 'duplicate'
sub _check_for_shortcut {
    my($self,$type) = @_;

    my $model = Genome::Model->get($self->model_id);

    my @similar_models = Genome::Model->get(sample_name => $model->sample_name,
                                            reference_sequence_name => $model->reference_sequence_name,
                                            read_aligner_name => $model->read_aligner_name,
                                            dna_type => $model->dna_type,
                                            genome_model_id => { operator => 'ne', value => $model->genome_model_id},
                                         );
    my @similar_model_ids = map { $_->genome_model_id } @similar_models;
    return unless (@similar_model_ids);
    my @possible_events = Genome::Model::Event->get(event_type => $self->event_type,
                                                    genome_model_event_id => {
                                                        operator => '!=',
                                                        value => $self->genome_model_event_id
                                                    },
                                                    event_status => ['Succeeded', 'Running'],
                                                    model_id => \@similar_model_ids,
                                                    run_id => $self->run_id,
                                                );

    foreach my $prior_event ( @possible_events ) {
        my $prior_model = Genome::Model->get(genome_model_id => $prior_event->model_id);
        # Do our model and the candidate model have the same number of sub-references?
        if (scalar($prior_model->get_subreference_names) != scalar($model->get_subreference_names)) {
            next;
        }

        # The bfq file is one of the first things created when align-reads is running, so
        # that's what we're testing for
        my $bfq_file_method = sprintf('%s_bfq_file_for_lane', $type);
        my $prior_bfq_file = $prior_event->$bfq_file_method;
        if (-f $prior_bfq_file) {
            # This is a good candidate to make symlinks to.  Note that the event we're linking to
            # may still be Running, in which case the target of these symlinks may not
            # exist yet.  We'll block at the end of execute() until they're done

            my $prior_alignments_dir = $prior_event->alignment_submaps_dir_for_lane;
            my @prior_alignment_files = map { sprintf("%s/%s_%s.map",$prior_alignments_dir,$_,$type) } 
                                        grep { $_ ne "all_sequences" }
                                        $prior_model->get_subreference_names(reference_extension=>'bfa');

            return 0 if (@prior_alignment_files == 0);  # The prior run didn't make the files we needed

            # Find the aligner output files
            my $unaligned_reads_file_method = sprintf('unaligned_%s_reads_file_for_lane',$type);
            my $prior_unaligned_reads_file = $prior_event->$unaligned_reads_file_method;
            my $this_unaligned_reads_file = $self->$unaligned_reads_file_method;
            symlink($prior_unaligned_reads_file, $this_unaligned_reads_file);

            # the bfq file
            #my $bfq_file_method = sprintf('%s_bfq_file_for_lane', $type);
            #my $prior_bfq_file = $prior_event->$bfq_file_method;
            my $this_bfq_file = $self->$bfq_file_method;
            symlink($prior_bfq_file, $this_bfq_file);

            # maq's output file
            my $output_file_method = sprintf('aligner_%s_output_file_for_lane',$type);
            my $prior_output_file = $prior_event->$output_file_method;
            my $this_output_file = $self->$output_file_method;
            symlink($prior_output_file, $this_output_file);

            my $this_alignments_dir = $self->alignment_submaps_dir_for_lane;
            mkdir $this_alignments_dir;

            foreach my $orig_file ( @prior_alignment_files ) {
                my($this_filename) = ($orig_file =~ m/.*\/(\S+?)$/);
                symlink($orig_file, $this_alignments_dir . '/' . $this_filename);
            }
            return $prior_event;
        }
    }

    return undef;
}
                                                    
                                                    


1;

