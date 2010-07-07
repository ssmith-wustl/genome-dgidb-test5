package Genome::InstrumentData::Alignment::Bowtie;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Alignment::Bowtie {
    is => ['Genome::InstrumentData::Alignment'],
    has_constant => [
        aligner_name => { value => 'Bowtie' },
    ],
};

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

sub alignment_file {
    my $self = shift;
    return $self->alignment_directory .'/all_sequences.bowtie';
}

sub unmapped_file {
    my $self = shift;
    return $self->alignment_directory .'/all_sequences.bowtie.unmapped';
}

sub max_map_file {
    my $self = shift;
    return $self->alignment_directory .'/all_sequences.bowtie.maxmapped';
}


sub output_files {
    my $self = shift;
    my @output_files;
    push @output_files, $self->alignment_file;
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
        die('Failed to verify_alignment_data.  Must run from 64-bit architecture.');
    }

    my $lock;
    unless ($self->_resource_lock) {
        $lock = $self->lock_alignment_resource;
    } else {
        $lock = $self->_resource_lock;
    }

    my $alignment_file = $self->alignment_file;
    my $errors;
    unless (-e $alignment_file) {
        $self->status_message('No alignment file found in alignment directory: '. $alignment_dir);
        return;
    } elsif (!$self->verify_aligner_successful_completion($alignment_file)) {
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

    unless ($self->unlock_alignment_resource) {
        $self->error_message('Failed to unlock alignment resource '. $lock);
        return;
    }
    return 1;
}

sub _run_aligner {
    my $self = shift;

    my $lock;
    unless ($self->_resource_lock) {
        $lock = $self->lock_alignment_resource;
    } else {
        $lock = $self->_resource_lock;
    }
    my $instrument_data = $self->instrument_data;
    my $reference_build = $self->reference_build;
    my $alignment_directory = $self->alignment_directory;

    $self->status_message("OUTPUT PATH: $alignment_directory\n");


    # we resolve these first, since we might just print the paths we work with then exit
#    my @input_pathnames = $self->input_pathnames;
    my @input_pathnames = $self->sanger_fastq_filenames;
    $self->status_message("INPUT PATH(S): @input_pathnames\n");

    # prepare the refseq
#    my $ref_seq_file =  $reference_build->full_consensus_path('bowtie');
    my $ref_seq_file =  Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.bowtie'; # Hack - hard-coded Bowtie reference
    unless ($ref_seq_file && -e "$ref_seq_file.1.ebwt") {
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


    # these are general params not infered from the above
    my $alignment_file = $self->alignment_file;
    my $aligner_params = $self->aligner_params || '-m 1 --best --strata -p 4';


    # RESOLVE A STRING OF ALIGNMENT PARAMETERS
    if ($is_paired_end && $insert_size && $insert_sd) {
        $aligner_params .= ' --minins '. ($insert_size - $insert_sd) .' --maxins '. ($insert_size + $insert_sd);
    }

#    my $files_to_align = join(' ',@input_pathnames);
    my $files_to_align = "";
    if($input_pathnames[1])
    {
	$files_to_align = "-1 $input_pathnames[0] -2 $input_pathnames[1]";
    }
    else
    {
	$files_to_align = "$input_pathnames[0]";
    }
    
#    my $cmdline = Genome::Model::Tools::Bowtie->path_for_Bowtie_version($self->aligner_version)
    my $cmdline = "bowtie"
        . sprintf(' %s %s %s ',
                  $aligner_params,
                  $ref_seq_file,
                  $files_to_align)
            . $alignment_file . ' 2>&1';
#    my @input_files = ($ref_seq_file, @input_pathnames);
    my @input_files = @input_pathnames;

    $self->status_message("COMMAND: $cmdline\n");

    my @output_files = ($alignment_file);
    Genome::Utility::FileSystem->shellcmd(
                                          cmd                         => $cmdline,
                                          input_files                 => \@input_files,
                                          output_files                => \@output_files,
                                          skip_if_output_is_present   => 1,
                                      );

    unless ($self->verify_aligner_successful_completion($alignment_file)) {
        $self->error_message('Failed to verify Bowtie successful completion from output file '. $alignment_file);
        die($self->error_message);
    }
    return 1;
}

sub process_low_quality_alignments {
    my $self = shift;
    $self->die_and_clean_up('Please implement process_low_quality_alignments for '. __PACKAGE__);
}

sub verify_aligner_successful_completion {
    my $self = shift;
    my $aligner_output_file = shift;

    unless ($aligner_output_file) {
        $aligner_output_file = $self->alignment_file;
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
        $aligner_output_file = $self->alignment_file;
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

sub sanger_fastq_filenames {

    my $self = shift;

    my $instrument_data = $self->instrument_data;

    my @sanger_fastq_pathnames;
    if ($self->{_sanger_fastq_pathnames}) {
        @sanger_fastq_pathnames = @{$self->{_sanger_fastq_pathnames}};
        my $errors;
        for my $sanger_fastq (@sanger_fastq_pathnames) {
            unless (-e $sanger_fastq && -f $sanger_fastq && -s $sanger_fastq) {
                $self->error_message('Missing or zero size sanger fastq file: '. $sanger_fastq);
                $self->die_and_clean_up($self->error_message);
            }
        }
    } else {
        my %params;
        if ($self->force_fragment) {
            if ($self->instrument_data_id eq $self->_fragment_seq_id) {
                $params{paired_end_as_fragment} = 2;
            } else {
                $params{paired_end_as_fragment} = 1;
            }
        }
        my @illumina_fastq_pathnames = $instrument_data->fastq_filenames(%params);
        my $counter = 0;
        for my $illumina_fastq_pathname (@illumina_fastq_pathnames) {
            my $sanger_fastq_pathname = $self->create_temp_file_path('sanger-fastq-'. $counter++);
            if ($instrument_data->resolve_quality_converter eq 'sol2sanger') {
                unless (Genome::Model::Tools::Maq::Sol2sanger->execute(
                                                                       use_version => '0.7.1', ### default to most recent
                                                                       solexa_fastq_file => $illumina_fastq_pathname,
                                                                       sanger_fastq_file => $sanger_fastq_pathname,
                                                                   )) {
                    $self->error_message('Failed to execute sol2sanger quality conversion.');
                    $self->die_and_clean_up($self->error_message);
                }
            } elsif ($instrument_data->resolve_quality_converter eq 'sol2phred') {
                unless (Genome::Model::Tools::Fastq::Sol2phred->execute(
                                                                        fastq_file => $illumina_fastq_pathname,
                                                                        phred_fastq_file => $sanger_fastq_pathname,
                                                                    )) {
                    $self->error_message('Failed to execute sol2phred quality conversion.');
                    $self->die_and_clean_up($self->error_message);
                }
            }
            unless (-e $sanger_fastq_pathname && -f $sanger_fastq_pathname && -s $sanger_fastq_pathname) {
                $self->error_message('Failed to validate the conversion of solexa fastq file '. $illumina_fastq_pathname .' to sanger quality scores');
                $self->die_and_clean_up($self->error_message);
            }
            push @sanger_fastq_pathnames, $sanger_fastq_pathname;
        }
        $self->{_sanger_fastq_pathnames} = \@sanger_fastq_pathnames;
    }
    return @sanger_fastq_pathnames;
}


1;

