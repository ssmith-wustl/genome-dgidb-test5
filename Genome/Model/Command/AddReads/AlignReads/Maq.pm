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

    # use maq to do the alignments
    foreach my $pass ( 'unique','duplicate' ) {
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
        if ($?) {
            my $rv = $? >> 8;
            $self->error_message("got a nonzero exit code ($rv) from maq map; something went wrong.  cmdline was $cmdline rv was $rv");
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
            # Actually we do, at the next step...
            #unlink($alignment_file);
        }  

    } # end foreach unique, duplicate

    return 1;
}


1;

