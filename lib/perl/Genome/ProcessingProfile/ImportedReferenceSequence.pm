package Genome::ProcessingProfile::ImportedReferenceSequence;

use strict;
use warnings;

use File::Copy;
use File::Path qw/make_path/;
use File::Spec;
use Genome;

class Genome::ProcessingProfile::ImportedReferenceSequence {
    is => 'Genome::ProcessingProfile',
    doc => "this processing profile does the file copying and indexing required to import a reference sequence fasta file"
};

# Define a custom exception that may be caught specifically so that any other type of exception falls through
use Exception::Class('Genome::ProcessingProfile::ImportedReferenceSequence::LocalException');

sub _die {
    my $error = shift;
    Genome::ProcessingProfile::ImportedReferenceSequence::LocalException->throw(error => $error);
}

sub _resolve_disk_group_name_for_build {
    return 'info_apipe_ref';
}

sub _execute_build {
    my $self = shift @_;

    eval {
        $self->_execute_build_try(@_);
    };
    if (my $e = Exception::Class->caught('Genome::ProcessingProfile::ImportedReferenceSequence::LocalException')) {
        $self->error_message($e->error);
        return;
    }

    return 1;
}

sub _execute_build_try {
    my $num_4_GiB = 4294967296;
    my ($self, $build) = @_;
    my $model = $build->model;

    if(!$model) {
        _die("Couldn't find model for build id " . $build->build_id . ".");
    }

    my $fastaSize = -s $build->fasta_file;
    unless(-e $build->fasta_file && $fastaSize > 0) {
        _die("Reference sequence fasta file \"" . $build->fasta_file . "\" is either inaccessible, empty, or non-existent.");
    }
    if($fastaSize >= $num_4_GiB) {
        my $error = "Reference sequence fasta file \"". $build->fasta_file . "\" is larger than 4GiB.  In order to accommodate " .
                    "BWA, reference sequence fasta files > 4GiB are not supported.  Such sequences must be broken up and each chunk must " .
                    "have its own build and model(s).  Support for associating multiple fastas with a single reference model is " .
                    "desired but will require modifying the alignment code.";
        _die($error);
    }

    $self->status_message("Copying fasta");
    my $out_dir = $build->data_directory;
    my $fasta_file_name = File::Spec->catfile($out_dir, 'all_sequences.fa');
    unless (copy($build->fasta_file, $fasta_file_name)) {
        _die("Failed to copy \"" . $build->fasta_file . "\" to \"$fasta_file_name\": $!.");
    }

    $self->status_message("Making bases files from fasta.");
    $self->_make_bases_files($fasta_file_name, $out_dir);

    $self->status_message("Doing bwa indexing.");
    my $bwaIdxAlg = ($fastaSize < 11000000) ? "is" : "bwtsw";
    if (system("bwa index -a $bwaIdxAlg $fasta_file_name") != 0) {
        _die('bwa indexing failed.');
    }

    $self->status_message("Doing maq fasta2bfa.");
    my $bfa = File::Spec->catfile($out_dir, 'all_sequences.bfa');
    if (system("maq fasta2bfa $fasta_file_name $bfa") != 0) {
        _die('maq fasta2bfa failed.');
    }

    $self->status_message("Doing samtools faidx.");
    if (system("samtools faidx $fasta_file_name") != 0) {
        _die('samtools faidx failed.');
    }

    # Reallocate to amount of space actually consumed if the build has an associated allocation and that allocation
    # has an absolute path the same as this build's data_path
    $self->status_message("Reallocating.");
    if (defined($build->disk_allocation) && $out_dir eq $build->disk_allocation->absolute_path) {
        my $duOut = `du -s -k $out_dir`;
		if ( $? == 0
		     && $duOut =~ /^(\d+)\s/
			 && $1 > 0 )
        {
            $build->disk_allocation->reallocate('kilobytes_requested' => $1);
        }
        else {
            _die("Failed to determine the amount of space actually consumed by \"$out_dir\" and therefore can not reallocate.");
        }
    }

    $self->status_message("Done.");
}

# This function makes a .bases file for each chromosome in all_sequences.fa.  The code to do this by reading
# all_sequences.fa one line at a time would be a lot simpler, but there is no guarantee that a single line
# of sequence data is smaller than the amount of available memory.  Consequently, the fasta is read in 1MiB
# chunks.
sub _make_bases_files {
    my ($self, $fasta_file_name, $out_dir) = @_;
    my $fasta = IO::File->new();
    if(!$fasta->open($fasta_file_name, '<')) {
        _die("Failed to open \"$fasta_file_name\".");
    }
    my $prepend_return = 1;
    my $chunk_len = 2**20;
    my $read_len;
    my $buff = '';
    my $write_buff;
    my $chrom_line_start_index;
    my $chrom_line;
    my $chrom;
    my $break_index;
    my $bases_file_name;
    my $bases = IO::File->new();
    my $force_read = 0;
    my $no_chrom_name = 0;
    
    for (;;) {
        if (length($buff) == 0 || $force_read) {
            $force_read = 0;
            $read_len = $fasta->read($buff, $chunk_len, length($buff));
            if (!defined($read_len) || $read_len <= 0) {
                last;
            }
            elsif ($prepend_return) {
                $buff = "\n" . $buff;
                $prepend_return = 0;
            }
        }
        if ($buff =~ /^\n>/) {
            # We are at a chromosome line
            $break_index = index($buff, "\n", 2);
            if ($break_index >= 0) {
                # Found the end of the chromosome line
                $chrom_line = substr($buff, 0, $break_index, '');
                if ( $chrom_line =~ /^\n>\s*(\w+)\s*$/ ||
                     $chrom_line =~ /^\n>\s*gi\|.*chromosome\s+([^[:space:][:punct:]]+)/i ||
                     $chrom_line =~ /^\n>\s*([^[:space:][:punct:]]+).*$/ )
                {
                    $chrom = $1;
                    $no_chrom_name = 0;
                    $self->status_message("$chrom");
                    $bases_file_name = File::Spec->catfile($out_dir, "$chrom.bases");
                    if(!$bases->open($bases_file_name, '>')) {
                        _die("Failed to open \"$bases_file_name\".");
                    }
                }
                else {
                    if (length($chrom_line) > 1024) {
                        $chrom_line = substr($chrom_line, 0, 1024);
                        $chrom_line .= '...';
                    }
                    $self->warning_message("Failed to parse the chromosome name from:$chrom_line.");
                    $no_chrom_name = 1;
                }
            }
            else {
                # Chromosome name line extends beyond the end of the chunk
                $force_read = 1;
            }
        }
        else {
            $chrom_line_start_index = index($buff, "\n>");
            if ($chrom_line_start_index > 0) {
                $write_buff = substr($buff, 0, $chrom_line_start_index, '');
            }
            else {
                if (!$bases->opened()) {
                    _die("First line of fasta file must begin with '>'.");
                }
                if (substr($buff, -1, -1) eq "\n") {
                    $prepend_return = 1;
                }
                $write_buff = $buff;
                $buff = '';
            }
            $write_buff =~ s/\n//g;
            if (length($write_buff) > 0 && !$no_chrom_name) {
                print $bases $write_buff;
            }
        }
    }
}

1;
