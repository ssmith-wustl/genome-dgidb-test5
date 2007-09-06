package Genome::Model::Command::AddReads::AlignReads::Maq;

use strict;
use warnings;

use UR;
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;

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

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub execute {
    my $self = shift;
    
    return 1;

    my $model = Genome::Model->get(id => $self->model_id);

    my $lanes;
    if ($self->sequencing_platform eq 'solexa') {
        $lanes = $self->limit_regions || '12345678';
    } else {
        $self->error_message("Determining limit_regions for sequencing_platform ".$self->sequencing_platform." is not implemented yet");
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

    my $gerald_dir = die "When this was written, \$self->full_path was a path to a bustard directory, not gerald.";
    my @geraldfiles = glob($gerald_dir . '/s_[' . $lanes . ']_sequence.txt*');
    foreach my $seqfile (@geraldfiles) {

            # convert quality values
            my $fastq_file = $working_dir . '/' . basename($seqfile);
            $fastq_file =~ s/\.txt/.fastq/x;
            system("maq sol2sanger $seqfile $fastq_file");

            # Convert the reads to the binary fastq format
            my $bfq_file = $working_dir . '/' . basename($seqfile);
            $bfq_file =~ s/\.txt/.bfq/x;
            system("maq fastq2bfq $fastq_file $bfq_file");

            #unless ($self->keep_fastq) {
            #        unlink $fastq_file;
            #}
    }

    # Part 2, use maq to do the alignments

    my @alignment_files;
    foreach my $lane ( split('', $lanes) ) {
        my $bfq_file = sprintf('%s/s_%d_sequence.bfq', $working_dir, $lane);
        unless (-r $bfq_file) {
            $self->error_message("bfq file $bfq_file does not exist");
            next;
        }

        my $this_lane_alignments_file = $working_dir . "/alignments_lane_$lane";
        push @alignment_files, $this_lane_alignments_file;
       
        my $maq_cmdline = sprintf('maq map %s %s %s %s', $model->read_aligner_params,
                                                         $this_lane_alignments_file,
                                                         $model->reference_sequence_file,
                                                         $bfq_file);
        system($maq_cmdline);
    }

    my $accumulated_alignments_file = $working_dir . "/alignments_run_" . $self->run_name;
    my $cmdline = "maq maq mapmerge $accumulated_alignments_file " . join(' ', @alignment_files);
    system($cmdline);
 
    unlink foreach @alignment_files;
        
    return 1;
}

1;

