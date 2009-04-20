package Genome::InstrumentData::Alignment;

use strict;
use warnings;

use Genome;
use Digest::MD5 qw(md5_hex);

class Genome::InstrumentData::Alignment {
    is => ['Genome::Utility::FileSystem'],
    has => [
        instrument_data                 => {
                                            is => 'Genome::InstrumentData',
                                            id_by => 'instrument_data_id'
                                        },
        instrument_data_id              => {
                                            is => 'Number',
                                            doc => 'the local database id of the instrument data (reads) to align'
                                        },
        aligner_name                    => {
                                            is => 'Text', default_value => 'maq',
                                            doc => 'the name of the aligner to use, maq, blat, newbler etc.'
                                        },
    ],
    has_optional => [
         aligner_version    => {
                                is => 'Text',
                                doc => 'the version of maq to use, i.e. 0.6.8, 0.7.1, etc.'
                            },
         aligner_params     => {
                                is => 'Text',
                                doc => 'any additional params for the aligner in a single string'
                            },
         reference_build    => {
                                is => 'Genome::Model::Build::ReferencePlaceholder',
                                id_by => 'reference_name',
                            },
         reference_name     => {
                                doc => 'the reference to use by EXACT name, defaults to NCBI-human-build36',
                                default_value => 'NCBI-human-build36'
                            },
    ],

};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;
    
    unless ($self->reference_build) {
        unless ($self->reference_name) {
            $self->error_message('No way to resolve reference build without reference_name or refrence_build');
            return;
        }
        my $ref_build = Genome::Model::Build::ReferencePlaceholder->get($self->reference_name);
        unless ($ref_build) {
            $ref_build = Genome::Model::Build::ReferencePlaceholder->create(
                                                                            name => $self->reference_name,
                                                                            sample_type => $self->instrument_data->sample_type,
                                                                        );
        }
        $self->reference_build($ref_build);
    }
    return $self;
}

sub create_allocation {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    unless ($instrument_data->calculate_alignment_estimated_kb_usage) {
        return;
    }
    my $disk_allocation = Genome::Disk::Allocation->allocate(
                                                             disk_group_name => 'info_alignments',
                                                             allocation_path => $self->resolve_alignment_subdirectory,
                                                             kilobytes_requested => $instrument_data->calculate_alignment_estimated_kb_usage,
                                                             owner_class_name => $instrument_data->class,
                                                             owner_id => $instrument_data->id,
                                                         );
    unless ($disk_allocation) {
        $self->error_message('Failed to get disk allocation');
        return;
    }
    return $disk_allocation;
}

sub get_or_create_allocation {
    my $self = shift;

    my $allocation = $self->get_allocation;
    if ($allocation) {
        return $allocation;
    }
    return $self->create_allocation;
}

sub get_allocation {
    my $self = shift;

    my $reference_sequence_name = $self->reference_name;
    my $instrument_data = $self->instrument_data;

    my $allocation_path = $self->resolve_alignment_subdirectory;

    my @instrument_data_allocations = $instrument_data->allocations;
    my @matches = grep { $_->allocation_path eq $allocation_path } @instrument_data_allocations;
    if (@matches) {
        if (scalar(@matches) > 1) {
            die('More than one allocation found for allocation_path: '. $allocation_path);
        }
        return $matches[0];
    }
    return;
}

sub resolve_alignment_subdirectory {
    my $self = shift;
    my $reference_sequence_name = $self->reference_name;

    my $instrument_data = $self->instrument_data;

    unless ($instrument_data->subset_name) {
        die ($instrument_data->class .'('. $instrument_data->id .') is missing the subset_name or lane!');
    }
    if ($instrument_data->is_external) {
        return sprintf('alignment_data/%s/%s/%s/%s_%s',
                       $self->aligner_label,
                       $reference_sequence_name,
                       $instrument_data->id,
                       $instrument_data->subset_name,
                       $instrument_data->id
                   );
    } else {
        unless ($instrument_data->run_name) {
            die ($instrument_data->class .'('. $instrument_data->id .') is missing the run_name!');
        }
        return sprintf('alignment_data/%s/%s/%s/%s_%s',
                       $self->aligner_label,
                       $reference_sequence_name,
                       $instrument_data->run_name,
                       $instrument_data->subset_name,
                       $instrument_data->id
                   );
    }
}

sub aligner_label {
    my $self = shift;

    my $aligner_name    = $self->aligner_name;
    my $aligner_version = $self->aligner_version;
    my $aligner_params = $self->aligner_params;

    return $aligner_name unless $aligner_version;

    $aligner_version =~ s/\./_/g;

    my $aligner_label = $aligner_name . $aligner_version;

    if ($aligner_params and $aligner_params ne '') {
        my $params_md5 = md5_hex($aligner_params);
        $aligner_label .= '/'. $params_md5;
    }

    return $aligner_label;
}


sub get_or_create_alignment_directory {
    my $self = shift;

    my $dir = $self->alignment_directory;
    unless ($dir) {
        my $allocation = $self->get_or_create_allocation;
        unless ($allocation) {
            $self->error_message('Failed to get or create alignment allocation.');
            die($self->error_message);
        }
        $dir = $self->alignment_directory;
        unless ($dir) {
            $self->error_message('Failed to get or create an alignment directory.');
            die($self->error_message);
        }
    }
    return $dir;
}

sub alignment_directory {
    my $self = shift;

    my $allocation = $self->get_allocation;
    unless ($allocation) {
        return;
    }
    return $allocation->absolute_path;
}

sub remove_alignment_directory {
    my $self = shift;

    my $allocation = $self->get_allocation;
    unless ($allocation) {
        die('No alignment allocation found for instrument data '. $self->instrument_data_id
            .' with aligner '. $self->aligner_name .' and refseq '. $self->reference_name);
    }
    my $allocation_path = $allocation->absolute_path;
    unless (File::Path::rmtree($allocation_path)) {
        $self->error_message('Failed to remove alignment data directory: '. $allocation_path .":  $!");
        die $self->error_message;
    }
    unless ($allocation->deallocate) {
        $self->error_message('Failed to deallocate alignment data directory disk space for allocator id '. $allocation->allocator_id);
        die $self->error_message;
    }
    return 1;
}

sub find_or_generate_alignment_data {
    my $self = shift;
    unless ($self->verify_alignment_data) {
        # delegate to the correct module by aligner name
        my $aligner_name;
        if ($self->aligner_name =~ /^(maq)\d_\d_\d/) {
            $aligner_name = $1
        } else {
            $aligner_name = $self->aligner_name;
        }
        my $aligner_ext = ucfirst($aligner_name);
        my $cmd = "Genome::InstrumentData::Command::Align::$aligner_ext";
	
	my %create_params = (
		reference_build => $self->reference_build,
		instrument_data => $self->instrument_data,
	);	        
	if ($self->aligner_version) {
		$create_params{'version'} = $self->aligner_version;
	}
	if ($self->aligner_params) {
		$create_params{'params'} = $self->aligner_params;
	}		
	my $align_cmd = $cmd->create(%create_params);
        $align_cmd->dump_status_messages($self->message_object('status'));
        unless ($align_cmd) {
            $self->error_message('Failed to create align command '. $cmd);
            return;
        }
        unless ($align_cmd->execute) {
            $self->error_message('Failed to execute align command '. $align_cmd->command_name ."\n".
                                 join("\n",$align_cmd->error_message) ."\n");
            return;
        }
        unless ($self->verify_alignment_data) {
            $self->error_message('Failed to verify existing alignment data in directory '. $self->alignment_directory);
            return;
        }
        $self->status_message('Finished aligning:'. "\n".  join("\n",$align_cmd->status_message) ."\n");
    }
    return 1;
}

#TODO: remove the "existing" from this method name
sub verify_alignment_data {
    my $self = shift;

    my $alignment_dir = $self->alignment_directory;
    return unless $alignment_dir;
    return unless -d $alignment_dir;

    my $reference_build = $self->reference_build;
    my @subsequence_names = grep { $_ ne 'all_sequences' } $reference_build->subreference_names(reference_extension => 'bfa');

    unless  (@subsequence_names) {
        @subsequence_names = 'all_sequences';
    }
    my $errors = 0;
    for my $subsequence_name (@subsequence_names) {
        my ($alignment_file) = $self->alignment_file_paths_for_subsequence_name($subsequence_name);
        unless ($alignment_file) {
            $errors++;
            $self->error_message('No alignment file found for subsequence '. $subsequence_name .' in alignment directory '. $self->alignment_directory);
        }
    }
    my @possible_unaligned_shortcuts= $self->unaligned_reads_list_paths;
    for my $possible_unaligned_shortcut (@possible_unaligned_shortcuts) {
        my $found_unaligned_reads_file = $self->check_for_path_existence($possible_unaligned_shortcut);
        if (!$found_unaligned_reads_file) {
            $self->error_message("Missing unaligned reads file '$possible_unaligned_shortcut'");
            $errors++;
        } elsif (!-s $possible_unaligned_shortcut) {
            $self->error_message("Unaligned reads file '$possible_unaligned_shortcut' found but zero size");
            $errors++;
        }
    }

    my @possible_aligner_output_shortcuts = $self->aligner_output_file_paths;
    for my $possible_aligner_output_shortcut (@possible_aligner_output_shortcuts) {
        my $found_aligner_output_file = $self->check_for_path_existence($possible_aligner_output_shortcut);
        if (!$found_aligner_output_file) {
            $self->error_message("Missing aligner output file '$possible_aligner_output_shortcut'.");
            $errors++;
        } elsif (!$self->verify_aligner_successful_completion($possible_aligner_output_shortcut)) {
            $errors++;
        }
    }
    if ($errors) {
        my @alignment_files = $self->alignment_file_paths;
        if (@alignment_files) {
            my $msg = 'REFUSING TO CONTINUE with partial map files in place in old directory:' ."\n";
            $msg .= join("\n",@alignment_files) ."\n";
            die($msg);
        }
        return;
    }
    $self->status_message('Alignment data verified: '. $alignment_dir);
    return 1;
}


#####ALIGNMENTS#####
#a glob for all alignment files
sub alignment_file_paths {
    my $self = shift;
    return unless -d $self->alignment_directory;
    return grep { -e $_ && $_ !~ /aligner_output/ }
            glob($self->alignment_directory .'/*.map*');
}

#a glob for subsequence alignment files
sub alignment_file_paths_for_subsequence_name {
    my $self = shift;
    my $subsequence_name = shift;
    unless (defined($subsequence_name)) {
        $self->error_message('No subsequence_name passed to method alignment_file_paths_for_subsequence_name.');
        return;
    }
    return unless -d $self->alignment_directory;
    my @files = grep { -e $_ && $_ !~ /aligner_output/ }
            glob($self->alignment_directory ."/${subsequence_name}.map*");
    return @files;

    # Now try the old format: $refseqid_{unique,duplicate}.map.$eventid
    #my $glob_pattern = sprintf('%s/%s_*.map.*', $alignment_dir, $ref_seq_id);
    #@files = grep { $_ and -e $_ } (
    #    glob($glob_pattern)
    #);
    #return @files;
}

#####ALIGNER OUTPUT#####
#a glob for existing aligner output files
sub aligner_output_file_paths {
    my $self=shift;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } glob($self->alignment_directory .'/*.map.aligner_output*');
}

#the fully quallified file path for aligner output
sub aligner_output_file_path {
    my $self = shift;
    my $file = $self->alignment_directory . $self->aligner_output_file_name;
    return $file;
}

sub aligner_output_file_name {
    my $self = shift;
    my $lane = $self->instrument_data->subset_name;
    my $file = "/alignments_lane_${lane}.map.aligner_output";
    return $file;
}

#####UNALIGNED READS LIST#####
#a glob for existing unaligned reads list files
sub unaligned_reads_list_paths {
    my $self = shift;
    my $subset_name = $self->instrument_data->subset_name;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } grep { $_ !~ /\.fastq$/ } glob($self->alignment_directory .'/*'.
                                                         $subset_name .'_sequence.unaligned*');
}

#the fully quallified file path for unaligned reads
sub unaligned_reads_list_path {
    my $self = shift;
    return $self->alignment_directory . $self->unaligned_reads_list_file_name;
}

sub unaligned_reads_list_file_name {
    my $self = shift;
    my $subset_name = $self->instrument_data->subset_name;
    return "/s_${subset_name}_sequence.unaligned";
}

#####UNALIGNED READS FASTQ#####
#a glob for existing unaligned reads fastq files
sub unaligned_reads_fastq_paths  {
    my $self=shift;
    my $subset_name = $self->instrument_data->subset_name;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } glob($self->alignment_directory .'/*'.
                               $subset_name .'_sequence.unaligned*.fastq');
}

#the fully quallified file path for unaligned reads fastq
sub unaligned_reads_fastq_path {
    my $self = shift;
    return $self->alignment_directory . $self->unaligned_reads_fastq_file_name;
}

sub unaligned_reads_fastq_file_name {
    my $self = shift;
    my $subset_name = $self->instrument_data->subset_name;
    return "/s_${subset_name}_sequence.unaligned.fastq";
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
    my $aligner_output_fh = IO::File->new($aligner_output_file);
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
        if ($$stats{'isPE'} != 1) {
            $self->error_message('Paired-end instrument data '. $instrument_data->id .' was not aligned as paired end data according to aligner output '. $aligner_output_file);
            return;
        }
    }
    while(<$aligner_output_fh>) {
        if (m/match_data2mapping/) {
            $aligner_output_fh->close();
            return 1;
        }
        if (m/\[match_index_sorted\] no reasonable reads are available. Exit!/) {
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

    my $fh = IO::File->new($aligner_output_file);
    unless($fh) {
        $self->error_message("unable to open maq's alignment output file:  " . $aligner_output_file);
        return;
    }
    my @lines = $fh->getlines;
    $fh->close;

    my ($line_of_interest)=grep { /total, isPE, mapped, paired/ } @lines;
    unless ($line_of_interest) {
        $self->error_message('Aligner summary statistics line not found');
        return;
    }
    my ($comma_separated_metrics) = ($line_of_interest =~ m/= \((.*)\)/);
    my @values = split(/,\s*/,$comma_separated_metrics);

    my %hashy_hash_hash;
    $hashy_hash_hash{total}=$values[0];
    $hashy_hash_hash{isPE}=$values[1];
    $hashy_hash_hash{mapped}=$values[2];
    $hashy_hash_hash{paired}=$values[3];
    return \%hashy_hash_hash;
}


###EVERYTHING BELOW THIS IS PROBABLY SPECIFIC TO MAQ AND MAY BECOME SEPARATE COMMANDS OR A PART OF THE ALIGN/MAQ COMMAND###
###SOME SUBROUTINES ABOVE MAY NEED COPIED BELOW THIS CHECKPOINT IF THEY ARE MAQ SPECIFIC###

sub sanger_bfq_filenames {
    my $self = shift;

    my @sanger_bfq_pathnames;
    if ($self->{_sanger_bfq_pathnames}) {
        @sanger_bfq_pathnames = $self->{_sanger_bfq_pathnames};
        my $errors;
        for my $sanger_bfq (@sanger_bfq_pathnames) {
            unless (-e $sanger_bfq && -f $sanger_bfq && -s $sanger_bfq) {
                $self->error_message('Missing or zero size sanger bfq file: '. $sanger_bfq);
                die($self->error_message);
            }
        }
    } else {
        my @sanger_fastq_pathnames = $self->sanger_fastq_filenames;
        my $counter = 0;
        for my $sanger_fastq_pathname (@sanger_fastq_pathnames) {
            my $sanger_bfq_pathname = $self->create_temp_file_path('sanger-bfq-'. $counter++);
            unless (Genome::Model::Tools::Maq::Fastq2bfq->execute(
                                                                  fastq_file => $sanger_fastq_pathname,
                                                                  bfq_file => $sanger_bfq_pathname,
                                                              )) {
                $self->error_message('Failed to execute fastq2bfq quality conversion.');
                die($self->error_message);
            }
            unless (-e $sanger_bfq_pathname && -f $sanger_bfq_pathname && -s $sanger_bfq_pathname) {
                $self->error_message('Failed to validate the conversion of sanger fastq file '. $sanger_fastq_pathname .' to sanger bfq.');
                die($self->error_message);
            }
            push @sanger_bfq_pathnames, $sanger_bfq_pathname;
        }
        $self->{_sanger_bfq_pathnames} = \@sanger_bfq_pathnames;
    }
    return @sanger_bfq_pathnames;
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
                die($self->error_message);
            }
        }
    } else {
        my @illumina_fastq_pathnames = $instrument_data->fastq_filenames;
        my $counter = 0;
        for my $illumina_fastq_pathname (@illumina_fastq_pathnames) {
            my $sanger_fastq_pathname = $self->create_temp_file_path('sanger-fastq-'. $counter++);
            if ($instrument_data->resolve_quality_converter eq 'sol2sanger') {
                unless (Genome::Model::Tools::Maq::Sol2sanger->execute(
                                                                       use_version => $self->aligner_version,
                                                                       solexa_fastq_file => $illumina_fastq_pathname,
                                                                       sanger_fastq_file => $sanger_fastq_pathname,
                                                                   )) {
                    $self->error_message('Failed to execute sol2sanger quality conversion.');
                    die($self->error_message);
                }
            } elsif ($instrument_data->resolve_quality_converter eq 'sol2phred') {
                unless (Genome::Model::Tools::Fastq::Sol2phred->execute(
                                                                        fastq_file => $illumina_fastq_pathname,
                                                                        phred_fastq_file => $sanger_fastq_pathname,
                                                                    )) {
                    $self->error_message('Failed to execute sol2phred quality conversion.');
                    die($self->error_message);
                }
            }
            unless (-e $sanger_fastq_pathname && -f $sanger_fastq_pathname && -s $sanger_fastq_pathname) {
                $self->error_message('Failed to validate the conversion of solexa fastq file '. $illumina_fastq_pathname .' to sanger quality scores');
                die($self->error_message);
            }
            push @sanger_fastq_pathnames, $sanger_fastq_pathname;
        }
        $self->{_sanger_fastq_pathnames} = \@sanger_fastq_pathnames;
    }
    return @sanger_fastq_pathnames;
}


1;
