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

    my $fastaSize = -s $self->build->fasta_file;
    unless(-e $self->build->fasta_file && $fastaSize > 0)
    {
        $self->status_message("Reference sequence fasta file \"" . $self->build->fasta_file . "\" is either inaccessible, empty, or non-existent.");
        return;
    }
    if($fastaSize >= $num4GiB)
    {
        $self->status_message("Reference sequence fasta file \"". $self->build->fasta_file . "\" is larger than 4GiB.  In order to accommodate " .
                              "BWA, reference sequence fasta files > 4GiB are not supported.  Such sequences must be broken up and each chunk must " .
                              "have its own build and model(s).  Support for associating multiple fastas with a single reference model is " .
                              "desired but will require modifying the alignment code.");
        return;
    }

    my ($allocation, $outDir, $subDir);

    $subDir = $model->name;
    if(defined($self->build->version))
    {
        $subDir .= '-v' . $self->build->version;
    }
    $subDir .= '-' . $self->build->build_id;

    # Make allocation unless the user wants to put the data in specific place and manage it himself
    if(defined($self->build->data_directory))
    {
        $outDir = $self->build->data_directory;
        if(!-d $outDir)
        {
            make_path($outDir);
            if(!-d $outDir)
            {
                self->status_message("\"$outDir\" does not exist and could not be created.");
                return;
            }
        }
    }
    else
    {
        my $allocationPath = 'reference_sequences/' . $subDir;
        # Space required is estimated to be three times the size of the reference sequence fasta
        $allocation = Genome::Disk::Allocation->allocate('allocation_path' => $allocationPath,
                                                         'disk_group_name' => 'info_apipe_ref',
                                                         'kilobytes_requested' => (3 * $fastaSize) / 1024,
                                                         'owner_class_name' => 'Genome::Model::Build::ImportedReferenceSequence',
                                                         'owner_id' => $self->build->build_id);
        $self->build->allocation($allocation);
        $self->build->data_directory($allocation->absolute_path);
        $outDir = $allocation->absolute_path;
    }

    # Copy the original fasta
    my $fasta = File::Spec->catfile($outDir, 'all_sequences.fasta');
    unless(copy($self->build->fasta_file, $fasta))
    {
        self->error_message("Failed to copy \"" . $self->build->fasta_file . "\" to \"$fasta\": $!.");
        return;
    }

    my $bwaIdxAlg = ($fastaSize < 11000000) ? "is" : "bwtsw";
    system("bwa index -a $bwaIdxAlg $fasta");

    my $bfa = File::Spec->catfile($outDir, 'all_sequences.bfa');
    system("maq fasta2bfa $fasta $bfa");

    system("samtools faidx $fasta");

    # Reallocate to amount of space actually consumed
    if(defined($allocation))
    {
        my $duOut = `du -s -k $outDir`;
		if ( $? == 0
		     && $duOut =~ /^(\d+)\s/
			 && $1 > 0 )
        {
            $allocation->reallocate('kilobytes_requested' => $1);
        }
        else
        {
            $self->status_message("Failed to determine the amount of space actually consumed by \"$outDir\" and therefore can not reallocate.");
            return;
        }
    }

    # Make a symlink for stuff that looks for ref seq data in the old place
    unless(symlink($self->build->data_directory, File::Spec->catpath('/gscmnt/839/info/medseq/reference_sequences', $subDir))
    {
        $self->status_message('Failed to symlink "' . File::Spec->catpath('/gscmnt/839/info/medseq/reference_sequences', $subDir) . '" -> "' . $self->build->data_directory . '".');
        return;
    }

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
