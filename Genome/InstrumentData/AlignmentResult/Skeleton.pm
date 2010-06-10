package Genome::InstrumentData::AlignmentResult::Skeleton;

use strict;
use warnings;
use File::Basename;

use Genome;

#  So, you want to build an aligner?  Follow these steps.
#
#  1) set aligner name in the UR class def
#  2) set required_rusage
#  3) Implement run_aligner
#  4) Implement aligner_params_for_sam_header
#
#  You also will want to create a Genome::InstrumentData::Command::Align::YOURCLASSHERE
#  so you can align from the command line too!

class Genome::InstrumentData::AlignmentResult::Skeleton {
    is => 'Genome::InstrumentData::AlignmentResult',
    
    # TODO: Put your aligner name here
    has_constant => [
        aligner_name => { value => 'skeleton', is_param=>1 },
    ],
};

sub required_arch_os { 'x86_64' }

#TODO: Put the LSF resources required to run the alignment here.
sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>10000] span[hosts=1] rusage[tmp=90000, mem=10000]' -M 10000000 -n 4";
}

#
#  Implement this method with the actual logic to run your aligner.
#  The pathnames for input files are passed in.
#
#  The expected output is an "all_sequences.sam" file in the scratch directory.
#  YOU MUST APPEND TO THIS FILE, NOT OVERWRITE.  This is because the calling code
#  may run multiple passes of run_aligner.  For example, when running trimming,
#  there may be two invocations - one with paired data, and one with a set of remaining
#  singleton reads whose mates were clipped too far in to be usable.
#
#  The sam file also needs to NOT have any SAM headers (i.e. lines starting with "@").
#  The pipeline adds its own detailed headers that are appropriate to the data.
#  Having headers here already will cause issues in the pipeline
#  downstream with picard merge.
#

sub _run_aligner {
    my $self = shift;
    my @input_pathnames = @_;


    # get refseq info
    my $reference_build = $self->reference_build;
    
    #TODO: This'll give you the path to a reference index in the reference directory ending in .fa
    #If your flavor of aligner uses a different file extension for its index, put it here.
    my $reference_fasta_path = $reference_build->full_consensus_path('fa');
    
    # Check the local cache on the blade for the fasta if it exists.
    if (-e "/opt/fscache/" . $reference_fasta_path) {
        $reference_fasta_path = "/opt/fscache/" . $reference_fasta_path
    }

    # This is your scratch directory.  Whatever you put here will be wiped when the alignment
    # job exits.
    my $scratch_directory = $self->temp_scratch_directory;
    
    # This is the alignment output directory.  Whatever you put here will be synced up to the
    # final alignment directory that gets a disk allocation.
    my $staging_directory = $self->temp_staging_directory;
 
    # This is the SAM file you should be appending to.  Dont forget, no headers!
    my $sam_file = $scratch_directory . "/all_sequences.bam";

    
    # TODO: implement your aligner logic here.  If you need to condition on whether the
    # data is single-ended or paired-ended, key off the number of files passed in (1=SE, 2=PE)
    # Under no circumstances should you ever get more than 2 files, if you do then that's bad and
    # you should die.
    
    if (@input_pathnames == 1) {
        $self->status_message("_run_aligner called in single-ended mode.");
    } elsif (@input_pathnames == 2) {
        $self->status_message("_run_aligner called in paired-end mode.");
    } else {
        $self->error_message("_run_aligner called with " . scalar @input_pathnames . " files.  It should only get 1 or 2!");
        die $self->error_message;
    }
    
    die "Skeleton aligner can't actually align.  Put your logic here and remove this die line.";

    

    # confirm that at the end we have a nonzero sam file, this is what'll get turned into a bam and
    # copied out.
    unless (-s $sam_file) {
        die "The sam output file $sam_file is zero length; something went wrong.";
    }
    
    # TODO:
    # If you have any log files from the aligner you're wrapping that you'd like to keep,
    # copy them out into the staging directory here.
    
    
    # TODO:
    # Do any last minute checks on the staged data and die if they fail.
    
    
    # If we got to here, everything must be A-OK.  AlignmentResult will take over from here
    # to convert the sam file to a BAM and copy everything out.
    
    return 1;
}

# TODO: This should be the command line used to run your aligner, not just the params.
# sorry for the mis-named method name, it'll get fixed soon.
#
# This will end up in our re-composed sam/bam header.

sub aligner_params_for_sam_header {
    my $self = shift;
    
    return "skeleton aln " . $self->aligner_params;
}

