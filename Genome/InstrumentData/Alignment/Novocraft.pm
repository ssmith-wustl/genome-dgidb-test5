package Genome::InstrumentData::Alignment::Novocraft;

use strict;
use warnings;

use Genome;
use File::Copy;

class Genome::InstrumentData::Alignment::Novocraft {
    is => ['Genome::InstrumentData::Alignment'],
    has_constant => [
        aligner_name => { value => 'novocraft' },
    ],
};

sub _resolve_subclass_name_for_aligner_name {
	return "Genome::InstrumentData::Alignment::Novocraft";
}

sub input_pathnames {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    my %params;
    if ($self->force_fragment) {
        if ($self->instrument_data_id eq $self->_fragment_seq_id) {
            $params{paired_end_as_fragment} = 2;
        } else {
            $params{paired_end_as_fragment} = 1;
        }
    }
    my @illumina_fastq_pathnames = $instrument_data->fastq_filenames(%params);
    return @illumina_fastq_pathnames;
}

sub alignment_bam_file_paths {
    my $self = shift;
    return $self->alignment_file;
}

sub alignment_file {
    my $self = shift;
    return $self->alignment_directory .'/all_sequences.bam';
}

sub aligner_output_file_path {
    my $self = shift;
    return $self->alignment_directory .'/all_sequences.aligner_output';
}


sub output_files {
    my $self = shift;
    my @output_files;
    push @output_files, $self->alignment_file;
    push @output_files, $self->aligner_output_file_path;
    return @output_files;
}

sub find_or_generate_alignment_data {
    my $self = shift;

    unless ($self->verify_alignment_data) {
        $self->_run_aligner();
    } else {
        $self->status_message("Existing alignment data is available and deemed correct.");
    }

    return 1;
}

sub verify_alignment_data {
    my $self = shift;

    my $alignment_dir = $self->alignment_directory;
    return unless $alignment_dir;
    return unless -d $alignment_dir;

    unless ( Genome::Config->arch_os =~ /64/ ) {
        $self->die('Failed to verify_alignment_data.  Must run from 64-bit architecture.');
    }

    my $lock;
    my $already_had_lock = 0;
    unless ($self->_resource_lock) {
        $lock = $self->lock_alignment_resource;
    } else {
        $already_had_lock = 1;
        $lock = $self->_resource_lock;
    }

    my $alignment_file = $self->alignment_file;
    my $errors;
    unless (-e $alignment_file) {
        $self->status_message('No alignment file found in alignment directory: '. $alignment_dir);
        return;
    } elsif (!$self->verify_aligner_successful_completion($self->aligner_output_file_path)) {
        $self->error_message('Failed to verify aligner successful completion');
        $errors++;
    }
    if ($errors) {
        my @output_files = $self->output_files;
        if (@output_files) {
            my $msg = 'REFUSING TO CONTINUE with files in place in alignment directory:' ."\n";
            $msg .= join("\n",@output_files) ."\n";
            $self->die_and_clean_up($msg);
        }
        return;
    }
    $self->status_message('Alignment data verified: '. $alignment_dir);
    # don't unlock if some caller lower on the stack had a lock
    unless ($already_had_lock) {
        unless ($self->unlock_alignment_resource) {
            $self->error_message('Failed to unlock alignment resource '. $lock);
            return;
        }
    }
    return 1;
}

sub _run_aligner {
    my $self = shift;

    my $lock;
    my $already_had_lock = 0;
    unless ($self->_resource_lock) {
        $lock = $self->lock_alignment_resource;
    } else {
        $already_had_lock = 1;
        $lock = $self->_resource_lock;
    }
    my $instrument_data = $self->instrument_data;
    my $reference_build = $self->reference_build;
    my $alignment_directory = $self->alignment_directory;

    $self->status_message("OUTPUT PATH: $alignment_directory\n");


    # we resolve these first, since we might just print the paths we work with then exit
    my @input_pathnames = $self->input_pathnames;
    $self->status_message("INPUT PATH(S): @input_pathnames\n");

    # prepare the refseq
    my $ref_seq_file =  $reference_build->full_consensus_path('ndx');
    unless ($ref_seq_file && -e $ref_seq_file) {
        $self->error_message("Reference build full consensus path '$ref_seq_file' does not exist.");
        die($self->error_message);
    }
    $self->status_message("REFSEQ PATH: $ref_seq_file\n");

    my $is_paired_end;
    my $insert_size;
    my $insert_sd;
    if ($instrument_data->is_paired_end && !$self->force_fragment) {
        $insert_sd = $instrument_data->sd_above_insert_size;
        $insert_size = $instrument_data->median_insert_size;
        $is_paired_end = 1;
    } else {
        $is_paired_end = 0;
    }

    # for novocraft we just need the 3' adaptor
    # commercial version also allows 5' adaptor trimming
    #my $adaptor_seq = $instrument_data->resolve_adaptor_seq;
    #unless ($adaptor_seq) {
    #    $self->die_and_clean_up("Failed to resolve adaptor sequence!");
    #}
    

    # these are general params not infered from the above
    my $aligner_params = '';
    my $threads = 1;
    if ($self->aligner_params) {
        if ($aligner_params =~ /(-c\s*(\d))/) {
            my $match = $1;
            $threads = $2;
            $aligner_params =~ s/$match//;
        }
        $aligner_params .= ' '. $self->aligner_params;
    };
    #TODO: Resolve the input read format(this is only necessary for old data(GAPipeline <v1.3)
    my $input_format = 'ILMFQ';
    
    # RESOLVE A STRING OF ALIGNMENT PARAMETERS
    if ($is_paired_end && $insert_size && $insert_sd) {
        $aligner_params .= ' -i '. $insert_size .' '. $insert_sd;
    }

    my $tmp_dir = File::Temp::tempdir( CLEANUP => 1 );
    my $files_to_align = join(' ',@input_pathnames);
    my $aligner_tool = Genome::Model::Tools::Novocraft::Novoalign->create(
        use_version => $self->aligner_version,
        novoindex_file => $ref_seq_file,
        fastq_files => $files_to_align,
        output_directory => $tmp_dir,
        output_format => 'SAM',
        input_format => $input_format,
        threads => $threads,
        params => $aligner_params,
    );

    unless ($aligner_tool->execute) {
        die ('Failed to execute command '. $aligner_tool->command_name);
    }

    unless ($self->generate_tcga_bam_file(
        sam_file => $aligner_tool->output_file,
        aligner_params => $aligner_tool->full_param_string,
    ) ) {
	my $error = $self->error_message;
	$self->error_message("Error creating BAM file from SAM file; error message was $error");
	return;
    }
    unless(copy($aligner_tool->log_file, $self->aligner_output_file_path)) {
        $self->error_message("Failed copying completed alignment file.  Undoing...");
        unlink($self->aligner_output_file_path);
        return;
    }
    
    unless ($self->verify_aligner_successful_completion($self->aligner_output_file_path)) {
        $self->error_message('Failed to verify novocraft successful completion from output file '. $self->aligner_output_file_path);
        $self->die_and_clean_up($self->error_message);
    }

    my $alignment_allocation = $self->get_allocation;

    if ($alignment_allocation) {
        unless ($alignment_allocation->reallocate) {
            $self->error_message('Failed to reallocate disk space for disk allocation: '. $alignment_allocation->id);
            $self->die_and_clean_up($self->error_message);
        }
    }
    
    # don't unlock if some caller lower on the stack had a lock
    unless ($already_had_lock) {
        unless ($self->unlock_alignment_resource) {
             $self->error_message('Failed to unlock alignment resource '. $lock);
             die $self->error_message;
        }
    }
    return 1;
}


sub verify_aligner_successful_completion {
    my $self = shift;
    my $aligner_output_file = shift;

    unless ($aligner_output_file) {
        $aligner_output_file = $self->aligner_output_file_path;
    }
    unless (-s $aligner_output_file) {
        $self->error_message("Aligner output file '$aligner_output_file' not found or zero size.");
        return;
    }
    my $aligner_output_fh = Genome::Utility::FileSystem->open_file_for_reading($aligner_output_file);
    unless ($aligner_output_fh) {
        $self->error_message("Can't open aligner output file $aligner_output_file: $!");
        return;
    }
    my $instrument_data = $self->instrument_data;
    if ($instrument_data->is_paired_end) {
        my $stats = $self->get_alignment_statistics($aligner_output_file);
        unless ($stats) {
            return;
        }
        if ($self->force_fragment) {
            if (defined($$stats{'Paired Reads'})) {
                $self->error_message('Paired-end instrument data '. $instrument_data->id .' was not aligned as fragment data according to aligner output '. $aligner_output_file);
                return;
            }
        }  else {
            if (!defined($$stats{'Paired Reads'})) {
                $self->error_message('Paired-end instrument data '. $instrument_data->id .' was not aligned as paired end data according to aligner output '. $aligner_output_file);
                return;
            }
        }
    }
    while(<$aligner_output_fh>) {
        if (m/^# Done.$/) {
            $aligner_output_fh->close();
            return 1;
        }
    }
    return;
}

sub get_alignment_statistics {
    my $self = shift;
    my $aligner_output_file = shift;
    unless ($aligner_output_file) {
        $aligner_output_file = $self->aligner_output_file_path;
    }
    unless (-s $aligner_output_file) {
        $self->error_message("Aligner output file '$aligner_output_file' not found or zero size.");
        return;
    }

    my $fh = Genome::Utility::FileSystem->open_file_for_reading($aligner_output_file);
    unless($fh) {
        $self->error_message("unable to open maq's alignment output file:  " . $aligner_output_file);
        return;
    }
    my @lines = $fh->getlines;
    $fh->close;
    my %hashy_hash_hash;
    my @comments = grep { /^#/ } @lines;
    foreach my $comment (@comments) {
        $comment =~ /^#\s+(.*)\:\s+(.*)/;
        my $key = $1;
        my $value = $2;
        if ($key && $value) {
            $hashy_hash_hash{$key} = $value;
        }
    }
    return \%hashy_hash_hash;
}

1;

