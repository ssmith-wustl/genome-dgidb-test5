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
    foreach my $pass ( @passes ) {
        # See if we can re-use data from another run, and just symlink to it
        my $shortcut = $self->_check_for_shortcut($pass);
        if (defined $shortcut) {
            next if $shortcut;
        }

        # Convert the fastq files into bfq files
    
        my $fastq_method = sprintf("sorted_%s_fastq_file_for_lane", $pass);
        my $fastq_pathname = $self->$fastq_method;
        unless (-f $fastq_pathname) {
            $self->error_message("fastq file does not exist $fastq_pathname");
            return;
        }
        
        my $bfq_method = sprintf("%s_bfq_file_for_lane", $pass);
        my $bfq_pathname = $self->$bfq_method;
        unless (-f $bfq_pathname) {
            system("$maq_pathname fastq2bfq $fastq_pathname $bfq_pathname");
        }

        # Do alignments 
        my $aligner_output_method = sprintf("aligner_%s_output_file_for_lane", $pass);
        my $aligner_output = $self->$aligner_output_method;

        my $reads_method = sprintf("unaligned_%s_reads_file_for_lane", $pass);
        my $reads_file = $self->$reads_method;

        my $alignment_file_method = sprintf("%s_alignment_file_for_lane", $pass);
        my $alignment_file = $self->$alignment_file_method();

        my $aligner_params = $model->read_aligner_params || '';
        my $cmdline = sprintf("$maq_pathname map %s -u %s %s %s %s %s > $aligner_output 2>&1",
                              $aligner_params,
                              $reads_file,
                              $alignment_file,
                              $ref_seq_file,
                              $bfq_pathname);

        print "running: $cmdline\n";
        system($cmdline);
#        if ($?) {
#            my $rv = $? >> 8;
#            $self->error_message("got a nonzero exit code ($rv) from maq map; something went wrong.  cmdline was $cmdline rv was $rv");
#            return;
#        }

        # use submap if necessary
        my @subsequences = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');

        if (@subsequences) {
            foreach my $seq (@subsequences) {
                my $alignments_dir = $self->alignment_submaps_dir_for_lane;
                unless (-d $alignments_dir ) {
                     mkdir($alignments_dir);
                }
                my $submap_target = sprintf("%s/%s_%s.map",$alignments_dir,$seq,$pass);
                
                # That last "1" is for the required (because of a bug) 'begin' parameter
                my $maq_submap_cmdline = "$maq_pathname submap $submap_target $alignment_file $seq 1";
            
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

    return 1;
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

    my @possible_events = Genome::Model::Event->get(event_type => $self->event_type,
                                                    event_status => 'Succeeded',
                                                    model_id => \@similar_model_ids,
                                                    run_id => $self->run_id,
                                                );

    foreach my $prior_event ( @possible_events ) {
        my $prior_alignments_dir = $prior_event->alignment_submaps_dir_for_lane;
        if (-d $prior_alignments_dir) {
            my @alignment_files = glob("$prior_alignments_dir/*$type.map");
            return 0 if (@alignment_files == 0);  # The prior run didn't make the files we needed

            my @subsequences = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');
            if (scalar(@alignment_files) != scalar(@subsequences)) {
                $self->error_message("The number of references for this model doesn't match the number of sequences found in event ".$prior_event->genome_model_event_id);
                die;
            }

            # This is a good candidate to make symlinks to

            # Find the aligner output files
            my $unaligned_reads_file_method = sprintf('unaligned_%s_reads_file_for_lane',$type);
            my $prior_unaligned_reads_file = $prior_event->$unaligned_reads_file_method;
            return 0 unless (-f $prior_unaligned_reads_file);
            my $this_unaligned_reads_file = $self->$unaligned_reads_file_method;
            symlink($prior_unaligned_reads_file, $this_unaligned_reads_file);

            # the bfq file
            my $bfq_file_method = sprintf('%s_bfq_file_for_lane', $type);
            my $prior_bfq_file = $prior_event->$bfq_file_method;
            return 0 unless (-f $prior_bfq_file);
            my $this_bfq_file = $self->$bfq_file_method;
            symlink($prior_bfq_file, $this_bfq_file);

            # maq's output file
            my $output_file_method = sprintf('aligner_%s_output_file_for_lane',$type);
            my $prior_output_file = $prior_event->$output_file_method;
            return 0 unless (-f $prior_output_file);
            my $this_output_file = $self->$output_file_method;
            symlink($prior_output_file, $this_output_file);

            my $this_alignments_dir = $self->alignment_submaps_dir_for_lane;
            mkdir $this_alignments_dir;

            foreach my $orig_file ( @alignment_files ) {
                return 0 unless $orig_file;
                my($this_filename) = ($orig_file =~ m/.*\/(\S+?)$/);
                return 0 unless $this_filename;
           
                symlink($orig_file, $this_alignments_dir . '/' . $this_filename);
            }
            return 1;
        }
    }

    return undef;
}
                                                    
                                                    


1;

