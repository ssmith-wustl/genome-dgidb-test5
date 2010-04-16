package Genome::ProcessingProfile::ImportedReferenceSequence;

use strict;
use warnings;

use File::Copy;
use File::Path qw/make_path/;
use File::Spec;
use Genome;

my $num4GiB = 4294967296;

class Genome::ProcessingProfile::ImportedReferenceSequence {
    is => 'Genome::ProcessingProfile',
    has => [
        server_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit the launcher or \'inline\''
        },
        job_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit jobs or \'inline\' to run them in the launcher'
        }
    ],
    doc => "this processing profile does the file copying and indexing required to import a reference sequence fasta file"
};

sub _execute_build {
    my ($self, $build) = @_;

    my $model = $build->model;

    if(!$model)
    {
        $self->error_message("Couldn't find model for build id " . $build->build_id . ".");
        return;
    }

    my $fastaSize = -s $build->fasta_file;
    unless(-e $build->fasta_file && $fastaSize > 0)
    {
        $self->status_message("Reference sequence fasta file \"" . $build->fasta_file . "\" is either inaccessible, empty, or non-existent.");
        return;
    }
    if($fastaSize >= $num4GiB)
    {
        $self->status_message("Reference sequence fasta file \"". $build->fasta_file . "\" is larger than 4GiB.  In order to accommodate " .
                              "BWA, reference sequence fasta files > 4GiB are not supported.  Such sequences must be broken up and each chunk must " .
                              "have its own build and model(s).  Support for associating multiple fastas with a single reference model is " .
                              "desired but will require modifying the alignment code.");
        return;
    }

    # Copy the original fasta
    my $outDir = $build->data_directory;
    my $fasta = File::Spec->catfile($outDir, 'all_sequences.fasta');
    unless(copy($build->fasta_file, $fasta))
    {
        $self->error_message("Failed to copy \"" . $build->fasta_file . "\" to \"$fasta\": $!.");
        return;
    }

    $self->status_message("Doing bwa indexing.");
    my $bwaIdxAlg = ($fastaSize < 11000000) ? "is" : "bwtsw";
    if(system("bwa index -a $bwaIdxAlg $fasta") != 0)
    {
        $self->error_message("bwa indexing failed.");
    }

    $self->status_message("Doing maq fasta2bfa.");
    my $bfa = File::Spec->catfile($outDir, 'all_sequences.bfa');
    if(system("maq fasta2bfa $fasta $bfa") != 0)
    {
        $self->error_message("maq fasta2bfa failed.");
    }

    $self->status_message("Doing samtools faidx.");
    if(system("samtools faidx $fasta") != 0)
    {
        $self->error_message("samtools faidx failed.");
    }

    # Reallocate to amount of space actually consumed if the build has an associated allocation and that allocation
    # has an absolute path the same as this build's data_path
    $self->status_message("Reallocating.");
    if(defined($build->disk_allocation) && $outDir eq $build->disk_allocation->absolute_path)
    {
        my $duOut = `du -s -k $outDir`;
		if ( $? == 0
		     && $duOut =~ /^(\d+)\s/
			 && $1 > 0 )
        {
            $build->disk_allocation->reallocate('kilobytes_requested' => $1);
        }
        else
        {
            $self->error_message("Failed to determine the amount of space actually consumed by \"$outDir\" and therefore can not reallocate.");
            return;
        }
    }

    $self->status_message("Done.");
    return 1;
}

sub _resolve_disk_group_name_for_build {
    return 'info_apipe_ref';
}



1;
