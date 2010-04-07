package Genome::Model::Event::Build::ImportedReferenceSequence::Run;

use strict;
use warnings;

use File::Copy;
use File::Spec;
use Fcntl;
use Fcntl qw/:seek/;
use POSIX qw/ceil/;

my $num4GiB = 4294967296;
my $num3p9GiB = 4187593112;
my $num10MiB = 10485760;

class Genome::Model::Event::Build::ImportedReferenceSequence::Run {
    is => 'Genome::Model::Event',
};

sub sub_command_sort_position { 40 }

sub help_brief {
    "Build for imported reference sequence models."
}

sub help_synopsis {
    return "genome-model build mymodel";
}

sub help_detail {
    "Build for imported reference sequence models.  This build makes bwa index, samtools " .
    "faidx, and maq bfa for the reference sequence fasta.  It will also split the reference " .
    "sequence fasta for bwa if the reference sequence fasta is large than 4 GiB."
}

sub execute {
    my $self = shift;
    my $model = $self->model;

    if(!$model)
    {
        $self->error_message("Couldn't find model for id ".$self->model_id);
        die;
    }
    $self->status_message("Found Model: " . $model->name);

    my $build = $self->build;

    my $inputFasta = $build->fasta_file;

    my ($allocationSize = undef, $allocationId, $allocationPath);
    if(!defined($self->build->data_directory)
    {
        ($allocationId, $allocationPath) = $self->makeDataDirectory();
    }

    my $dstFastas = copyAndSplitFasta($inputFasta, File::Spec->catfile($allocationPath, 'all_sequences.fasta'));

    my $bwa_idx_alg = ($size < 11000000) ? "is" : "bwtsw";

    print "Will index with bwa $bwa_idx_alg\n";
   
    my $samtools_version = Genome::Model::Tools::Sam->path_for_samtools_version($self->sam_version);
    print "Using samtools version $samtools_version\n";
    my $bwa_version = Genome::Model::Tools::Bwa->create->bwa_path();
    print "Using bwa version $bwa_version\n";
    my $maq_version = Genome::Model::Tools::Maq->create->maq_path();

    print "Submitting requests to the queue to perform indexing.  You'll be sent an email from LSF with the output when they're done.\n";

    print "Submitting a BWA index request.\n";
    $self->_bsub_invoke(rusage=> ($bwa_idx_alg eq "bwtsw" ? "rusage[mem=4000]' -M 4000000" : ""),
                        job_name => 'bwa-idx',
                        cmd=> $bwa_version . " index -a $bwa_idx_alg $new_fasta_path");
    
    my $new_bfa_path = sprintf("%s/all_sequences.bfa", $path); 
    print "Submitting a Maq fasta2bfa request.\n";
    $self->_bsub_invoke(job_name => 'maq-fasta2bfa',
                        cmd=> $maq_version . " fasta2bfa $new_fasta_path $new_bfa_path");
    
    print "Submitting a Samtools faidx request.\n";
    $self->_bsub_invoke(job_name => 'samtools-faidx',
                        cmd=> $samtools_version . " faidx $new_fasta_path");

    # Reallocate to amount of space actually consumed

    return 1;
}

# Estimate required size of data directory, generate a name for it, and make an allocation for it
sub makeDataDirectory
{
    $self = shift @_;
    $name = $self->model->name;

    $allocPath = File::Spec->catdir('reference_sequences', );
}

# ** This code works and has been tested.  However, the rest of the pipeline doesn't cope with reference
# sequence model builds with fastas that have been split into multiple chunks.  Such references must be
# made into multiple models with their own respective builds that have one fasta each.
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
