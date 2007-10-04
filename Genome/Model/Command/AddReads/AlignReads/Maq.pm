package Genome::Model::Command::AddReads::AlignReads::Maq;

use strict;
use warnings;

use UR;
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;
use Date::Calc;
use File::stat;

use App::Lock;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
);

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

sub execute {
    my $self = shift;
    
    my $model = Genome::Model->get(id => $self->model_id);

    my $lanes;
    
    # ensure the reference sequence exists.
    
    my $ref_seq_file =  $model->reference_sequence_path . "/bfa";
    
    unless (-e $ref_seq_file) {
        $self->error_message(sprintf("reference sequence file %s does not exist.  please verify this first.", $ref_seq_file));
        return;
    }
    
    if ($self->run->sequencing_platform eq 'solexa') {
        $lanes = $self->run->limit_regions || '12345678';
    } else {
        $self->error_message("Determining limit_regions for sequencing_platform ".$self->run->sequencing_platform." is not implemented yet");
        return;
    }

    my $working_dir = $self->resolve_run_directory;

    # Make sure the output directory exists
    unless (-d $working_dir) {
        $self->error_message("working directory $working_dir does not exist, please run assign-run first");
        return;
    }

    # Part 1, convert the files to a different format
    # Why are we converting them?

    my $gerald_dir = $self->run->full_path;
    my @geraldfiles = glob($gerald_dir . '/s_[' . $lanes . ']_sequence.txt*');
    foreach my $seqfile (@geraldfiles) {

            # convert quality values
            my $fastq_file = $working_dir . '/' . File::Basename::basename($seqfile);
            $fastq_file =~ s/\.txt/.fastq/x;
            system("maq sol2sanger $seqfile $fastq_file");

            # Convert the reads to the binary fastq format
            my $bfq_file = $working_dir . '/' . File::Basename::basename($seqfile);
            $bfq_file =~ s/\.txt/.bfq/x;
            system("maq fastq2bfq $fastq_file $bfq_file");

            #unless ($self->keep_fastq) {
            #        unlink $fastq_file;
            #}
    }

    # Part 2, use maq to do the alignments

    $DB::single = 1;
    my @alignment_files;
    foreach my $lane ( split('', $lanes) ) {
        my $bfq_file = sprintf('%s/s_%d_sequence.bfq', $working_dir, $lane);
        unless (-r $bfq_file) {
            $self->error_message("bfq file $bfq_file does not exist");
            next;
        }

        my $this_lane_alignments_file = $working_dir . "/alignments_lane_$lane";
        push @alignment_files, $this_lane_alignments_file;
       
       
        my $maq_cmdline = sprintf('maq map %s %s %s %s', $model->read_aligner_params || '',
                                                         $this_lane_alignments_file,
                                                         $ref_seq_file,
                                                         $bfq_file);
	
	print $maq_cmdline;
      
        system($maq_cmdline);
    }

    my $model_dir = $model->data_directory;
    
    my $accumulated_alignments_file = $model_dir . $self->_resolve_accumulated_alignments_file();
    my $accum_tmp = $accumulated_alignments_file . "." . $$;
    
    # Only one process is allwoed to manipulate the accumulated alignment file for the model
    # at a time
    unless ($model->lock_resource(resource_id=>$accumulated_alignments_file)) {
        $self->error_message("Can't get lock for accumulated alignment $accumulated_alignments_file");
        return undef;
    }

    if (!-f $accumulated_alignments_file && @alignment_files == 1) {
	my $rv = system("mv $alignment_files[0] $accumulated_alignments_file");
        if ($rv) {
            $self->error_message("exit code from moving $alignment_files[0] $accumulated_alignments_file was nonzero");
            return;
        }
    } else {
        my $cmdline = "maq mapmerge $accum_tmp " . join(' ', (@alignment_files, $accumulated_alignments_file));
        my $merge_ret_val = system($cmdline);
    
        if (! -f $accum_tmp || $merge_ret_val) {
            $self->error_message("got a nonzero return value from mapmerge, or the accumulated alignment temp file $accum_tmp doesn't exist.  mapmerge apparently failed.");
            return;
        }
    
       rename($accum_tmp, $accumulated_alignments_file);
    }
 
    #unlink foreach @alignment_files;
        
    return 1;
}

#
#
sub _resolve_accumulated_alignments_file {
    my $self = shift;
    my $model = Genome::Model->get(id => $self->model_id);
    
    my $model_dir = $model->data_directory;
    my $accumulated_alignments_filename = sprintf("/alignments_to_merge_%s_%s_%s-", Date::Calc::Today);
    
    my $iter = 1;
    
    while (-e "$model_dir/$accumulated_alignments_filename.$iter" && stat("$model_dir/$accumulated_alignments_filename.$iter")->size > 5000000000) {
        $iter++;
    }
    
    return $accumulated_alignments_filename.$iter;
}


1;

