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

    # Make a symlink for stuff that looks for ref seq data in the old place
    $self->status_message("Making symlink.");
    my $subDir = $model->name;
    if(defined($build->version))
    {
        $subDir .= '-v' . $build->version;
    }
    $subDir .= '-' . $build->build_id;
    $self->status_message(sprintf("symlink(%s, %s)\n", $build->data_directory, File::Spec->catdir('/gscmnt/839/info/medseq/reference_sequences', $subDir)));
    unless(symlink($build->data_directory, File::Spec->catdir('/gscmnt/839/info/medseq/reference_sequences', $subDir)))
    {
        $self->error_message('Failed to symlink "' . File::Spec->catdir('/gscmnt/839/info/medseq/reference_sequences', $subDir) . '" -> "' . $build->data_directory . '".');
        return;
    }

    $self->status_message("Done.");
    return 1;
}


# ehvatum: The following code works and has been tested.  However, the rest of the pipeline doesn't cope
# with reference sequence model builds with fastas that have been split into multiple chunks.  Such
# references must be made into multiple models with their own respective builds that have one fasta each.


#use Fcntl;
#use Fcntl qw/:seek/;
#use POSIX qw/ceil/;
#
#my $num3p9GiB = 4187593112;
#my $num10MiB = 10485760;
#
# Copy fasta at src to dst.  If src is larger than 4 GiB, src is copied to dst AND src is copied to
# dst_split000.originalextension, dst_split001.originalextension, .. in chunks of at most 3.9GiB.  The
# filenames of all resulting created files are returned as a reference to an array.  Execution fails
# if src contains a single read and associated comment larger than 4GiB.
#sub copyAndSplitFasta
#{
#    my ($self, $src, $dst);
#    unless(($self, $src, $dst) = @_)
#    {
#        $self->error_message("Genome::Model::Event::Build::ImportedReferenceSequence::Run->copy(..): too few arguments supplied.");
#        die;
#    }
#
#    my copied = [];
#
#    unless(open(SRC, '<' . $src))
#    {
#        self->error_message("Failed to open input fasta file \"$src\".\n");
#        die;
#    }
#    my $srcSize = (stat(SRC))[7];
#
#    # Make split fastas for BWA if required
#    if($srcSize > $num4GiB)
#    {
#        my ($dstNameBase, $dstExtension, $dstSplit);
#        my ($dstDir, $dstUnsplitName);
#        ($dstDir, $dstUnsplitName) = (File::Spec->splitpath($dst))[1, 2];
#        if($dstUnsplitName =~ /^(.+)\.([^. ]+)$/)
#        {
#            $dstNameBase = $1;
#            $dstExtension = $2;
#        }
#        else
#        {
#            $dstNameBase = $dstUnsplitName;
#            $dstExtension = '';
#        }
#        my $segmentIndex = 0;
#        my $segmentFrst = 0;
#        my ($segmentLast, $copyReadBuff, $scanReadBuff, $currPos, $foundRelPos, $foundPos, $remaining, $readCount, $readRet, $writeRet);
#        my $lastChunk = 0;
#        # Each iteration writes a single chunk of at most 3.9GiB
#        for(;;)
#        {
#            $segmentLast = $segmentFrst + $num3p9GiB;
#            if($segmentLast >= $srcSize)
#            {
#                $segmentLast = $srcSize - 1;
#                $lastChunk = 1;
#            }
#            $dstSplit = File::Spec->catfile($dstDir, sprintf("${dstNameBase}_split%03d.$dstExtension", $segmentIndex));
#            unless(sysopen(DST, $dstSplit, O_WRONLY | O_CREAT | O_NDELAY | O_TRUNC))
#            {
#                $self->error_message("Failed to open \"$dstSplit\".");
#                die;
#            }
#            unless($lastChunk)
#            {
#                # Each iteration looks backward 1024 bytes to find the beginning of the read that extends beyond the end of the
#                # chunk.
#                for($currPos = $segmentLast;;)
#                {
#                    $remaining = $currPos - $segmentFrst + 1;
#                    if($remaining <= 0)
#                    {
#                        # The read extending beyond the end of the chunk is greater than 3.9GiB; we can't split the fasta between
#                        # reads and must report an error and exit.
#                        $self->error_message("A comment + read exists that is larger than 3.9GiB.  Therefore the fasta cannot be safely split for BWA.");
#                        die;
#                    }
#                    # Leave overlap in order to catch \n> split on the leading edge of the last 1024 byte scan
#                    $readCount = ($remaining > 1020) ? 1020 : $remaning;
#                    $currPos -= $readCount;
#                    seek(SRC, $currPos, SEEK_SET);
#                    $readRet = read(SRC, $scanReadBuff, 1024);
#                    {
#                    if(!defined($readRet) || $readRet < $readCount)
#                    {
#                        $self->error_message("Failed to read from \"$src\".");
#                        die;
#                    }
#                    $foundRelPos = rindex($scanReadBuff, "\n>");
#                    $foundPos = $currPos + $foundRelPos;
#                    if($foundRelPos != -1)
#                    {
#                        last;
#                    }
#                }
#                if($foundPos - 4 <= $segmentFrst)
#                {
#                    $self->error_message("A comment + read exists that is larger than 3.9GiB.  Therefore the fasta cannot be safely split for BWA.");
#                    die;
#                }
#                $segmentLast = $foundPos;
#                seek(SRC, $segmentFrst, SEEK_SET);
#            }
#            # Copy ten megabytes at a time into the chunk
#            for($currPos = $segmentFrst; $currPos <= $segmentLast; $currPos += $readCount)
#            {
#                $readCount = $segmentLast - $currPos + 1;
#                if($readCount > $num10MiB)
#                {
#                    $readCount = $num10MiB;
#                }
#                $readRet = read(SRC, $copyReadBuff, $readCount);
#                if(!defined($readRet) || $readRet < $readCount)
#                {
#                    $self->error_message("Failed to read from \"$src\".");
#                    die;
#                }
#                $writeRet = syswrite(DST, $copyReadBuff, $readRet);
#                if(!defined($writeRet) || $writeRet < $readCount)
#                {
#                    $self->error_message("Failed to write to \"$dstSplit\": ${!}.");
#                    die;
#                }
#            }
#            close(DST);
#            push(@$copied, $dstSplit);
#            $segmentFrst = $segmentLast + 1;
#            if($segmentFrst >= $srcSize)
#            {
#                last;
#            }
#            ++$segmentIndex;
#        }
#    }
#    close(SRC);
#
#    # Copy the original fasta
#    unless(copy($src, $dst))
#    {
#        self->error_message("Failed to copy \"$src\" to \"$dst\": $!.");
#        die;
#    }
#    unshift(@$copied, $dst);
#
#    return $copied;
#}

1;
