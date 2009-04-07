package Genome::InstrumentData::Command::Align::Maq;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Maq::Map::Writer;

class Genome::InstrumentData::Command::Align::Maq {
    is => ['Genome::Utility::FileSystem','Command'],
    has_input => [
        instrument_data                 => {
                                            is => 'Genome::InstrumentData',
                                            id_by => 'instrument_data_id'
                                        },
        instrument_data_id              => {
                                            is => 'Number',
                                            doc => 'the local database id of the instrument data (reads) to align'
                                        },
    ],
    has_optional_param => [
        reference_build                 => {
                                            is => 'Genome::Model::Build::ReferencePlaceholder',
                                            id_by => 'reference_name',
                                        },
        reference_name                  => {
                                            doc => 'the reference to use by EXACT name, defaults to NCBI-human-build36',
                                            default_value => 'NCBI-human-build36'
                                        },
        version                         => {
                                            is => 'Text', default_value => '0.7.1',
                                            doc => 'the version of maq to use, i.e. 0.6.8, 0.7.1, etc.'
                                        },
        params                          => {
                                            is => 'Text', default_value => '', 
                                            doc => 'any additional params for the aligner in a single string'
                                        },
    ],
    has_constant => [
        aligner_name                    => { value => 'maq' },
    ],
    has_optional => [
                     _alignment         => {
                                            is => 'Genome::InstrumentData::Alignment',
                                        },
                 ],
    doc => 'align instrument data using maq (see http://maq.sourceforge.net)',
};

sub help_synopsis {
return <<EOS
genome instrument-data align maq -r NCBI-human-build36 -i 2761701954

genome instrument-data align maq -r NCBI-human-build36 -i 2761701954 -v 0.6.5

genome instrument-data align maq --reference-name NCBI-human-build36 --instrument-data-id 2761701954 --version 0.6.5

genome instrument-data align maq -i 2761701954 -v 0.6.5
EOS
}

sub help_detail {
return <<EOS
Launch the maq aligner in a standard way and produce results ready for the genome modeling pipeline.

See http://maq.sourceforge.net.

Also see Genome::Model::Tools::Maq::AlignReads, for a lower-level interface to maq.
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self->reference_build) {
        unless ($self->reference_name) {
            $self->error_message('No way to resolve reference build without reference_name or refrence_build');
            return;
        }
        my $ref_build = Genome::Model::Build::ReferencePlaceholder->get($self->reference_name);
        unless ($ref_build) {
            $ref_build = Genome::Model::Build::ReferencePlaceholder->create(
                                                                            name => $self->reference_name,
                                                                            sample_type => 'dna',
                                                                        );
        }
        $self->reference_build($ref_build);
    }
    unless ($self->_alignment) {
        my $alignment = Genome::InstrumentData::Alignment->create(
                                                                  instrument_data => $self->instrument_data,
                                                                  reference_build => $self->reference_build,
                                                                  aligner_name => $self->aligner_name,
                                                                  aligner_version => $self->version,
                                                                  aligner_params => $self->params,
                                                              );
        $self->_alignment($alignment);
    }
    return $self;
}

sub execute {
    my $self = shift;

    my $alignment = $self->_alignment;
    my $instrument_data = $alignment->instrument_data;
    my $reference_build = $alignment->reference_build;

    # we resolve these first, since we might just print the paths we work with then exit
    my @input_pathnames = $instrument_data->fastq_filenames;
    $self->status_message("INPUT PATHS: @input_pathnames\n");

    # prepare the refseq
    my $ref_seq_path =  $reference_build->data_directory;
    my $ref_seq_file =  $reference_build->full_consensus_path('bfa');
    unless (-e $ref_seq_file) {
        $self->error_message(sprintf("reference sequence file %s does not exist.  please verify this first.", $ref_seq_file));
        return;
    }
    $self->status_message("REFSEQ PATH: $ref_seq_file\n");

    my $alignment_directory = $alignment->get_or_create_alignment_directory;
    # check the status of this data set
    # be sure the check is atomic...
    my $resource_lock_name = $alignment_directory . '.generate';
    my $lock = $self->lock_resource(resource_lock => $resource_lock_name, max_try => 2);
    unless ($lock) {
        $self->status_message("This data set is still being processed by its creator.  Waiting for lock...");
        $lock = $self->lock_resource(resource_lock => $resource_lock_name);
        unless ($lock) {
            $self->error_message("Failed to get lock!");
            return;
        }
    }
    if ($alignment->verify_alignment_data) {
        $self->status_message("Existing alignment data is available and deemed correct.");
        $self->unlock_resource(resource_lock => $lock);
        return 1;
    } elsif ( -d $alignment_directory) {
        #We can remove the current alignment directory because we have the lock
        $self->status_message('Alignment directory exists but failed to verify data. Removing old alignment directory '. $alignment_directory);
        $alignment->remove_alignment_directory;
        $alignment_directory = $alignment->get_or_create_alignment_directory;
    } else {
        $self->status_message("No alignment files found...beginning processing and setting marker to prevent simultaneous processing.");
    }

    $self->status_message("OUTPUT PATH: $alignment_directory\n");
    # do this in an eval block so we can unlock the resource cleanly when we finish
    eval {

        # the base directory for results
        unless ($self->create_directory($alignment_directory)) {
            die('Failed to create directory '. $alignment_directory);
        }

        # resolve sample type
        my $sample_type = $instrument_data->sample_type;
        unless (defined($sample_type)) {
            $self->error_message('Sample type not defined for instrument data');
            die($self->error_message);;
        }

        ###input/output files
        my $alignment_file = $self->create_temp_file_path('all.map');
        unless ($alignment_file) {
            $self->error_message('Failed to create temp alignment file for all sequences');
            die($self->error_message);
        }

        ###upper bound insert param
        my $upper_bound_on_insert_size;
        if ($instrument_data->is_paired_end) {
            my $sd_above = $instrument_data->sd_above_insert_size;
            my $median_insert = $instrument_data->median_insert_size;
            $upper_bound_on_insert_size= ($sd_above * 5) + $median_insert;
            unless($upper_bound_on_insert_size > 0) {
                $self->status_message("Unable to calculate a valid insert size to run maq with. Using 600 (hax)");
                $upper_bound_on_insert_size= 600;
            }
            # TODO: extract additional details from the read set
            # about the insert size, and adjust the maq parameters.
            # $aligner_params .= " -a $upper_bound_on_insert_size";
        }

        my %params = (
            ref_seq_file            => $ref_seq_file,
            files_to_align_path     => join("|", @input_pathnames),
            execute_sol2sanger      => 'y',
            use_version             => $alignment->aligner_version,
            align_options           => $alignment->aligner_params,
            dna_type                => $sample_type,
            alignment_file          => $alignment_file,
            aligner_output_file     => $alignment->aligner_output_file_path,
            unaligned_reads_file    => $alignment->unaligned_reads_list_path,
            upper_bound             => $upper_bound_on_insert_size,
        );
        $self->status_message("Alignment params:\n" . Data::Dumper::Dumper(\%params));

        $self->status_message("Executing aligner...");
        my $alignments = Genome::Model::Tools::Maq::AlignReads->execute(%params);
        $self->status_message("Aligner executed.");

        ##############################################

        # in some cases maq will "work" but not make an unaligned reads file
        # this happens when all reads are filtered out
        # make an empty file to represent our zero-item list of unaligned reads
        unless (-e $alignment->unaligned_reads_list_path) {
            if (my $fh = IO::File->new(">".$alignment->unaligned_reads_list_path)) {
                $self->status_message("Made empty unaligned reads file since that file is was not generated by maq.");
            } else {
                $self->error_message("Failed to make empty unaligned reads file!: $!");
            }
        }
        my $cmd = '/gscmnt/sata114/info/medseq/pkg/maq/branches/lh3/maq-xp/maq-xp pileup -t '. $alignment->aligner_output_file_path .' 2>&1';
        my $line = `$cmd`;
        my ($evenness)=($line=~/(\S+)\%$/);
        IO::File->new(">$alignment_directory/evenness")->print($evenness);

        $DB::single = $DB::stopper;

        my @subsequences = grep {$_ ne "all_sequences"} $reference_build->subreference_names(reference_extension=>'bfa');

        # break up the alignments by the sequence they match, if necessary
        # my $map_split = Genome::Model::Tools::Maq::MapSplit->execute(
        #   map_file => $alignment_file,
        #   submap_directory => $alignment_directory,
        #   reference_names => \@subsequences,
        # );
        my $mapsplit_cmd = Genome::Model::Tools::Maq->path_for_mapsplit_version($alignment->aligner_version);
        if (@subsequences) {
            my $cmd = "$mapsplit_cmd " . $alignment_directory . "/ $alignment_file " . join(',',@subsequences);
            my $rv = system($cmd);
            if($rv) {
                #arbitrary convention set up with homemade mapsplit and mapsplit_long..return 2 if file is empty.
                if($rv/256 == 2) {
                    my $first_subsequence = $subsequences[0];
                    my ($empty_map_file) = $alignment->alignment_file_paths_for_subsequence_name($first_subsequence);
                    unless ($empty_map_file) {
                        $self->error_message('Failed to find empty map file after return value 2 from mapsplit comand '. $cmd);
                        die $self->error_message;
                    }
                    unless (-s $empty_map_file) {
                        $self->error_message('Empty map file '. $empty_map_file .' does not have size.');
                        die $self->error_message;
                    }
                    for my $subsequence (@subsequences) {
                        if ($subsequence eq $first_subsequence) { next; }
                        my $subsequence_map_file = $alignment_directory .'/'. $subsequence .'.map';
                        unless (File::Copy::copy($empty_map_file,$subsequence_map_file)) {
                            $self->error_message('Failed to copy empty map file '. $empty_map_file .' to '. $subsequence_map_file .":  $!");
                            die $self->error_message;
                        }
                    }
                } else {
                    $self->error_message("Failed to run map split on alignment file $alignment_file");
                    die $self->error_message;
                }
            }
        } else {
            @subsequences = 'all_sequences';
            my $all_sequences_map_file = $alignment_directory .'/all_sequences.map';
            unless (File::Copy::copy($alignment_file,$all_sequences_map_file)) {
                $self->error_message('Failed to copy map file from '. $alignment_file .' to '. $all_sequences_map_file);
                die $self->error_message;
            }
        }

        my $errors;
        for my $subsequence (@subsequences) {
            my @found = $alignment->alignment_file_paths_for_subsequence_name($subsequence);
            unless (@found) {
                $self->error_message("Failed to find map file for subsequence name $subsequence!");
                $errors++;
            }
        }
        if ($errors) {
            my @files = glob($alignment_directory . '/*');
            $self->error_message("Files in dir are:\n\t" . join("\n\t",@files) . "\n");
            die('Failed to find map files after alignment');
        }
        return 1;
    };

    if ($@) {
        my $exception = $@;
        $alignment->remove_alignment_directory;
        eval { $self->unlock_resource(resource_lock => $resource_lock_name); };
        die ($exception);
    }

    unless ($self->process_low_quality_alignments) {
        $self->error_message('Failed to process_low_quality_alignments');
        $self->unlock_resource(resource_lock => $lock);
        return;
    }

    unless ($alignment->verify_alignment_data) {
        $self->error_message('Alignment data failed to verify after alignment');
        $self->unlock_resource(resource_lock => $lock);
        return;
    }
    $self->unlock_resource(resource_lock => $lock);

    my $alignment_allocation = $alignment->get_allocation;
    if ($alignment_allocation) {
        unless ($alignment_allocation->reallocate) {
            $self->error_message('Failed to reallocate disk space for disk allocation: '. $alignment_allocation->id);
            return;
        }
    }
    return 1;
}


sub process_low_quality_alignments {
    my $self = shift;

    my $alignment = $self->_alignment;

    my $unaligned_reads_file = $alignment->unaligned_reads_list_path;
    my @unaligned_reads_files = $alignment->unaligned_reads_list_paths;

    if (-s $unaligned_reads_file . '.fastq' && -s $unaligned_reads_file) {
        $self->status_message("SHORTCUTTING: ALREADY FOUND MY INPUT AND OUTPUT TO BE NONZERO");
        return 1;
    }
    elsif (-s $unaligned_reads_file) {
        my $command = Genome::Model::Tools::Maq::UnalignedDataToFastq->execute(
            in => $unaligned_reads_file, 
            fastq => $unaligned_reads_file . '.fastq',
        );
        unless ($command) {die "Failed Genome::Model::Tools::Maq::UnalignedDataToFastq for $unaligned_reads_file";}
    }
    else {
        foreach my $unaligned_reads_files_entry (@unaligned_reads_files){
            my $command = Genome::Model::Tools::Maq::UnalignedDataToFastq->execute(
                in => $unaligned_reads_files_entry, 
                fastq => $unaligned_reads_files_entry . '.fastq'
            );
            unless ($command) {die "Failed Genome::Model::Tools::Maq::UnalignedDataToFastq for $unaligned_reads_files_entry";}
        }
    }

    unless (-s $unaligned_reads_file || @unaligned_reads_files) {
        $self->error_message("Could not find any unaligned reads files.");
        return;
    }

    return 1;
}




1;
