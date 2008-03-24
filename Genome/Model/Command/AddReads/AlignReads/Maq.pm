package Genome::Model::Command::AddReads::AlignReads::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;

class Genome::Model::Command::AddReads::AlignReads::Maq {
    is => 'Genome::Model::Event',
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
    
    my $model = Genome::Model->get(id => $self->model_id);

$DB::single = 1;

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

    # Convert the fastq files into bfq files
    my $unique_fastq = $self->sorted_unique_fastq_file_for_lane;
    my $unique_bfq = $self->unique_bfq_file_for_lane;
    my $duplicate_fastq = $self->sorted_redundant_fastq_file_for_lane;
    my $duplicate_bfq = $self->redundant_bfq_file_for_lane;

    if (-f $unique_fastq and ! -f $unique_bfq) {
        system("maq fastq2bfq $unique_fastq $unique_bfq");
    }
    if (-f $duplicate_fastq and ! -f $duplicate_bfq) {
        system("maq fastq2bfq $duplicate_fastq $duplicate_bfq");
    }

    my $this_lane_alignments_file = $self->alignment_file_for_lane();

    my $unaligned_reads_file = $self->unaligned_reads_file_for_lane();
       
    my $bfq_files = $unique_bfq;
    if ($self->model->multi_read_fragment_strategy eq "EliminateAllDuplicates") {
        1;
    } else {
        $bfq_files .= " $duplicate_bfq";
    }

    # Do the alignments
    my $maq_cmdline = sprintf('maq map %s -u %s %s %s %s %s', $model->read_aligner_params || '',
                                                              $unaligned_reads_file,
                                                              $this_lane_alignments_file,
                                                              $ref_seq_file,
                                                              $bfq_files);
	
    print "$maq_cmdline\n";

    my $maq_fh = IO::Handle->new();
    open($maq_fh, "$maq_cmdline 2>&1 |");
    unless ($maq_fh) {
        $self->error_message("problem starting maq: $!\nCommand line was $maq_cmdline");
        return;
    }

    my $maq_results = '';
    while(<$maq_fh>) {
        if (m/match_data2mapping/) {   # They're interested in seeing these lines
            $maq_results .= $_;
        }
    }
    $maq_fh->close();

    if ($?) {
        my $rv = $? >> 8;
        $self->error_message("got a nonzero exit code ($rv) from maq map; something went wrong.  cmdline was $maq_cmdline rv was $rv");
        return;
    }
    # write out the lines we saved
    my $results_file = $this_lane_alignments_file . ".matchdata";
    my $fh = IO::File->new(">$results_file");
    unless ($fh) {
        $self->error_message("Can't create $results_file for writing: $!");
        return;
    }
    $fh->print($maq_results);
    $fh->close();
       

    # use submap if necessary
    my @subsequences = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');

    if (@subsequences) {
        foreach my $seq (@subsequences) {
            unless (-d "$this_lane_alignments_file.submaps") {
                 mkdir("$this_lane_alignments_file.submaps");
            }
            my $submap_target = sprintf("%s.submaps/%s.map",$this_lane_alignments_file,$seq);
                
            # That last "1" is for the required 'begin' parameter
            my $maq_submap_cmdline = "maq submap $submap_target $this_lane_alignments_file $seq 1";
            
            print $maq_submap_cmdline, "\n";
                
            my $rv = system($maq_submap_cmdline);
            if ($rv) {
                 $self->error_message("got a nonzero return value from maq submap; cmdline was $maq_submap_cmdline");
                 return;
            }
        }
       
        # Oops.  The next step (accept reads) needs this map file.  We can
        # delete it there
        ## After we do the submaps, we don't need the original map file anymore
        #unlink($this_lane_alignments_file);
    }

    return 1;
}


1;

