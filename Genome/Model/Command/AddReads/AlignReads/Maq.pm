package Genome::Model::Command::AddReads::AlignReads::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use Genome::Model::Command::AddReads::AlignReads;

class Genome::Model::Command::AddReads::AlignReads::Maq {
    is => [
        'Genome::Model::Command::AddReads::AlignReads',
        'Genome::Model::Command::MaqSubclasser'
    ],
    has => [
        alignment_file_paths => {
            doc => "the paths to to the map files",
            calculate_from => ['read_set_directory','run_subset_name'],
            calculate => q|
                return unless -d $read_set_directory;;
                return grep { -e $_ } glob("${read_set_directory}/*${run_subset_name}.submaps/*.map");
            |,
        },
        aligner_output_file_paths => {
            doc => "the paths to the filed which captured maq's standard output and error",
            calculate_from => ['read_set_directory','run_subset_name'],
            calculate => q|
                return unless -d $read_set_directory;
                return grep { -e $_ } glob("${read_set_directory}/*${run_subset_name}.map.aligner_output");
            |,
        },
        poorly_aligned_reads_list_paths => {
            doc => "the path(s) to the file(s) which list poorly aligned reads",
            calculate_from => ['read_set_directory','run_subset_name'],
            calculate => q|
                return unless -d $read_set_directory;;
                return grep { -e $_ } grep { $_ !~ /\.fastq$/ } glob("${read_set_directory}/*${run_subset_name}_sequence.unaligned.*");
            |,
        },
        poorly_aligned_reads_fastq_paths => {
            doc => "the path(s) to the fastq(s) of poorly aligned reads",
            calculate_from => ['read_set_directory','run_subset_name'],
            calculate => q|
                return unless -d $read_set_directory;;
                return grep { -e $_ } glob("${read_set_directory}/*${run_subset_name}_sequence.unaligned.*.fastq");
            |,
        },
        contaminants_file_path => {
            doc => "the paths to the file containing adaptor sequence and other contaminants to screen",
            calculate_from => ['read_set_directory'],
            calculate => q|
                return unless -d $read_set_directory;;
                return grep { -e $_ } glob("${read_set_directory}/adaptor_sequence_file");
            |,
        },
        input_read_file_paths => {
            doc => "the paths to the files which captured maq's standard output and error",
            calculate_from => ['read_set_directory','run_subset_name'],
            calculate => q|
                unless (-d $read_set_directory) {
                    $self->error_message("read set directory '$read_set_directory' does not exist");
                    return;
                }
                $self->status_message("Looking for input read files in '$read_set_directory'\n");
                return grep { -e $_ } glob("${read_set_directory}/s_${run_subset_name}_sequence*.sorted.fastq");
            |,
        },
        unique_reads_across_library     => { via => 'read_set' },
        duplicate_reads_across_library  => { via => 'read_set' },
        read_length                     => {
                                            doc => "an accessor to return the read_length",
                                            calculate_from => ['read_set'],
                                            calculate => q| if ($read_set->read_length <= 0) {
                                                                die('Impossible value for read_length field. seq_id:'. $read_set->seq_id);
                                                            }
                                                            return $read_set->read_length;
                                                          |,
                                        },
        _calculate_total_read_count     => {
                                            doc => "an accessor to return the number of reads",
                                            calculate_from => ['read_set'],
                                            calculate => q| if ($read_set->clusters <= 0) {
                                                                die('Impossible value for clusters field. seq_id:'. $read_set->seq_id);
                                                            }
                                                            return $read_set->clusters;
                                                          |,
                                        },
        _alignment_file_paths_unsubmapped => {
            doc => "the paths to to the map files before submapping (not always available)",
            calculate => q|
                return unless -d $read_set_directory;;
                return grep { -e $_ } glob("${read_set_directory}/*${run_subset_name}.map");
            |,
            calculate_from => ['read_set_directory','run_subset_name'],
        },
            # deprecated
            output_data_dir => {
                                doc => "The path at which the model stores all of its private data for a given run",
                                calculate_from => ['read_set_directory'],
                                calculate => q|
                                    return $read_set_directory
                                |,
                                is_constant => 1,
                                is_deprecated => 1,
        },

        #make accessors for common metrics
        (
            map {
                $_ => { via => 'metrics', to => 'value', where => [name => $_], is_mutable => 1 },
            }
            qw/total_read_count/
        ),
    ],
};

sub help_brief {
    "Use maq to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads maq --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

# maq map file for all this lane's alignments

sub read_set_alignment_file_for_refseq {
    my $self = shift;
    my $ref_seq_id = shift;
    my $event_id = $self->id;
    return $self->read_set_alignment_directory . "/$ref_seq_id.map.$event_id";
}

sub aligner_output_file {
    my $self = shift;
    my $event_id = $self->id;
    my $lane = $self->read_set->subset_name;
    my $file = $self->read_set_alignment_directory . "/alignments_lane_${lane}.map.$event_id";
    $file =~ s/\.map\./\.map.aligner_output\./g;
    return $file;
}

sub unaligned_reads_file {
    my $self = shift;
    my $event_id = $self->id;
    my $read_set = $self->read_set;
    my $lane = $read_set->subset_name;
    return $self->read_set_alignment_directory . "/s_${lane}_sequence.unaligned.$event_id";
}

sub metrics_for_class {
    my $class = shift;

    my @metric_names = qw(
                          total_read_count
                          total_reads_passed_quality_filter_count
                          total_bases_passed_quality_filter_count
                          poorly_aligned_read_count
                          contaminated_read_count
                          aligned_read_count
                          aligned_base_pair_count
                          unaligned_read_count
                          unaligned_base_pair_count
                          total_base_pair_count
    );

    return @metric_names;
}

sub total_reads_passed_quality_filter_count {
    my $self = shift;
    return $self->get_metric_value('total_reads_passed_quality_filter_count');
}

sub _calculate_total_reads_passed_quality_filter_count {
    my $self = shift;

    my $total_reads_passed_quality_filter_count;
    do {
        no warnings;

        if (defined $self->unique_reads_across_library && defined $self->duplicate_reads_across_library) {
            $total_reads_passed_quality_filter_count = ($self->unique_reads_across_library + $self->duplicate_reads_across_library);
        }
        unless ($total_reads_passed_quality_filter_count) {
            my @f = $self->input_read_file_paths;
            if (!@f) {
                $self->error_message("No input read files found");
                return;
            }
            my ($wc) = grep { /total/ } `wc -l @f`;
            $wc =~ s/total//;
            $wc =~ s/\s//g;
            if ($wc % 4) {
                warn "run $a->{id} has a line count of $wc, which is not divisible by four!"
            }
            $total_reads_passed_quality_filter_count = $wc/4;
        }
    };
    return $total_reads_passed_quality_filter_count;
}

sub total_bases_passed_quality_filter_count {
    my $self = shift;
    return $self->get_metric_value('total_bases_passed_quality_filter_count');
}

sub _calculate_total_bases_passed_quality_filter_count {
    my $self = shift;

    my $total_bases_passed_quality_filter_count = $self->total_reads_passed_quality_filter_count * $self->read_length;
    return $total_bases_passed_quality_filter_count;
}

sub poorly_aligned_read_count {
    my $self = shift;
    
    return $self->get_metric_value('poorly_aligned_read_count');
}

sub _calculate_poorly_aligned_read_count {
    my $self = shift;

    #unless ($self->should_calculate) {
    #    return 0;
    #}
    
    my $total = 0;
    for my $f ($self->poorly_aligned_reads_list_paths) {
        my $fh = IO::File->new($f);
        $fh or die "Failed to open $f to read.  Error returning value for poorly_aligned_read_count.\n";
        while (my $row = $fh->getline) {
            $total++
        }
    }
    return $total;
}

sub contaminated_read_count {
    my $self = shift;
    return $self->get_metric_value('contaminated_read_count');
}

sub _calculate_contaminated_read_count {
    my $self = shift;

    my @f = $self->aligner_output_file_paths;
    my $total = 0;
    for my $f (@f) {
        my $fh = IO::File->new($f);
        $fh or die "Failed to open $f to read.  Error returning value for contaminated_read_count.\n";
        my $n;
        while (my $row = $fh->getline) {
            if ($row =~ /\[ma_trim_adapter\] (\d+) reads possibly contains adaptor contamination./) {
                $n = $1;
                last;
            }
        }
        unless (defined $n) {
            #$self->warning_message("No adaptor information found in $f!");
            next;
        }
        $total += $n;
    }
    return $total;
}

sub aligned_read_count {
    my $self = shift;
    return $self->get_metric_value('aligned_read_count');
}

sub _calculate_aligned_read_count {
    my $self = shift;
    my $aligned_read_count = $self->total_reads_passed_quality_filter_count - $self->poorly_aligned_read_count - $self->contaminated_read_count;
    return $aligned_read_count;
}

sub aligned_base_pair_count {
    my $self = shift;
    return $self->get_metric_value('aligned_base_pair_count');
}

sub _calculate_aligned_base_pair_count {
    my $self = shift;

    my $aligned_base_pair_count = $self->aligned_read_count * $self->read_length;
    return $aligned_base_pair_count;
}
sub unaligned_read_count {
    my $self = shift;
    return $self->get_metric_value('unaligned_read_count');
}

sub _calculate_unaligned_read_count {
    my $self = shift;
    my $unaligned_read_count = $self->poorly_aligned_read_count + $self->contaminated_read_count;
    return $unaligned_read_count;
}

sub unaligned_base_pair_count {
    my $self = shift;
    return $self->get_metric_value('unaligned_base_pair_count');
}

sub _calculate_unaligned_base_pair_count {
    my $self = shift;
    my $unaligned_base_pair_count = $self->unaligned_read_count * $self->read_length;
    return $unaligned_base_pair_count;
}

sub total_base_pair_count {
    my $self = shift;
    return $self->get_metric_value('total_base_pair_count');
}

sub _calculate_total_base_pair_count {
    my $self = shift;

    my $total_base_pair_count = $self->total_read_count * $self->read_length;
    return $total_base_pair_count;
}

sub prepare_input {
    my ($self, $read_set, $seq_dedup) = @_;

    my $lane = $read_set->subset_name;
    my $read_set_desc = $read_set->full_name . "(" . $read_set->id . ")";
    my $gerald_directory = $read_set->_run_lane_solexa->gerald_directory;
    unless ($gerald_directory) {
    
        die "No gerald directory in the database for or $read_set_desc"
    }
    unless (-d $gerald_directory) {
        die "No gerald directory on the filesystem for $read_set_desc: $gerald_directory";
    }
    my $solexa_output_path =  "$gerald_directory/s_${lane}_sequence.txt";
    my $aligner_path = $self->aligner_path('read_aligner_name');
   
    # find or create a sanger fastq 
    my $fastq_pathname;
    if ($seq_dedup) {
        die "sequence-based deduplication is not supported at this time";
        my $fastq_method = "sorted_unique_fastq_file_for_lane";
        $fastq_pathname = $self->$fastq_method;
        unless (-f $fastq_pathname) {
            $self->error_message("fastq file does not exist $fastq_pathname");
            return;
        }
        if (-z $fastq_pathname) {
            $self->error_message("fastq file has zero size $fastq_pathname");
            return;
        }
        $self->status_message("Found sequence-deduplicated fastq at $fastq_pathname");
    }
    unless ($fastq_pathname) {
        $fastq_pathname = $self->create_temp_file_path('fastq');
        $self->shellcmd(
            cmd => "$aligner_path sol2sanger $solexa_output_path $fastq_pathname",
            input_files => [$solexa_output_path],
            output_files => [$fastq_pathname],
            skip_if_output_is_present => 1,
        );
    }

    # create a bfq
    my $bfq_pathname = $self->create_temp_file_path('bfq');
    unless ($bfq_pathname) {
        die "Failed to create temp file for bfq!";
    }
    
    $self->shellcmd(
        cmd => "$aligner_path fastq2bfq $fastq_pathname $bfq_pathname",
        input_files => [$fastq_pathname],
        output_files => [$bfq_pathname],
        skip_if_output_is_present => 1,
    );

    return $bfq_pathname;
}

sub execute {
    my $self = shift;
    
$DB::single = 1;

    my $model = $self->model;

    # prepare the refseq
    my $ref_seq_path =  $model->reference_sequence_path;    
    my $ref_seq_file =  $ref_seq_path . "/all_sequences.bfa";
    unless (-e $ref_seq_file) {
        $self->error_message(sprintf("reference sequence file %s does not exist.  please verify this first.", $ref_seq_file));
        return;
    }

    # prepare the reads
    my $read_set = $self->read_set;
    my $seq_dedup = $model->is_eliminate_all_duplicates;
    my $bfq_pathname = $self->prepare_input($read_set,$seq_dedup);

    # prepare paths for the results
    my $read_set_alignment_directory = $self->read_set_alignment_directory;
    unless (-d $read_set_alignment_directory) {
        $self->create_directory($read_set_alignment_directory);
    }        
    my $alignment_file = $self->create_temp_file_path('all.map');
    my $aligner_output_file = $self->aligner_output_file;
    my $unaligned_reads_file = $self->unaligned_reads_file;
    
    # resolve adaptor file
    # TODO: get fresh from LIMS
    my $adaptor_file;
    my @dna = GSC::DNA->get(dna_name => $model->sample_name);
    if (@dna == 1) {
        if ($dna[0]->dna_type eq 'genomic dna') {
            $adaptor_file = '/gscmnt/sata114/info/medseq/adaptor_sequences/solexa_adaptor_pcr_primer';
        } elsif ($dna[0]->dna_type eq 'rna') {
            $adaptor_file = '/gscmnt/sata114/info/medseq/adaptor_sequences/solexa_adaptor_pcr_primer_SMART';
        }
    }
    unless (-e $adaptor_file) {
        $self->error_message("Adaptor file $adaptor_file not found!: $!");
        return;
    }
    
    # prepare the alignment command
    my $aligner_path = $self->aligner_path('read_aligner_name');
    my $aligner_params = $model->read_aligner_params || '';
    $aligner_params = join(' ', $aligner_params, '-d', $adaptor_file);
    my $cmdline = 
        $aligner_path
        . sprintf(' map %s -u %s %s %s %s %s > ',
                          $aligner_params,
                          $unaligned_reads_file,
                          $alignment_file,
                          $ref_seq_file,
                          $bfq_pathname) 
        . $aligner_output_file 
        . ' 2>&1';

    # run the aligner
    $self->shellcmd(
        cmd                         => $cmdline,
        input_files                 => [$ref_seq_file, $bfq_pathname],
        output_files                => [$alignment_file, $unaligned_reads_file, $aligner_output_file],
        skip_if_output_is_present   => 1,
    );
    
    # look through the output file and make sure maq actually finished completely
    unless ($self->_check_maq_successful_completion($aligner_output_file)) {
        return;
    }

$DB::single = 1;
    # break up the alignments by the sequence they match, if necessary
    my @subsequences = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');
    my $map_split = Genome::Model::Tools::Maq::MapSplit->execute(
        map_file => $alignment_file,
        submap_directory => $self->read_set_alignment_directory,
        reference_names => \@subsequences,
    );
    unless($map_split) {
        $self->error_message("Failed to run map split on alignment file $alignment_file");
        return;
    }
    
    for my $output_file ($map_split->output_files) {
        my $new_file_path = $output_file .'.'. $self->id;
        unless (rename($output_file,$new_file_path)) {
            $self->error_message("Failed to rename file '$output_file' => '$new_file_path'");
            return;
        }
    }

    $self->generate_metric($self->metrics_for_class);

    return 1;
}


sub verify_successful_completion {
    my ($self) = @_;

    my $model = $self->model;
    # does this model specify to keep or eliminate duplicate reads
    my @passes = ('unique') ;
    unless ($model->is_eliminate_all_duplicates) {
        push @passes, 'duplicate';
    }
    foreach my $pass ( @passes ) {
        my $aligner_output_method = sprintf("aligner_%s_output_file_for_lane", $pass);
        my $aligner_output = $self->$aligner_output_method;
        unless (-f $aligner_output) {
            if ($pass eq 'duplicate') {
                next;
            } else {
                $self->error_message("Aligner output file not found for $pass '$aligner_output'");
                return;
            }
        }
        unless ($self->_check_maq_successful_completion($aligner_output)) {
            if ($pass eq 'duplicate') {
                next;
            }
            return;
        }
    }
    return 1;
}


sub _check_maq_successful_completion {
    my($self,$output_filename) = @_;

    my $aligner_output_fh = IO::File->new($output_filename);
    unless ($aligner_output_fh) {
        $self->error_message("Can't open aligner output file $output_filename: $!");
        return;
    }

    while(<$aligner_output_fh>) {
        if (m/match_data2mapping/) {
            $aligner_output_fh->close();
            return 1;
        }
    }

    $self->error_message("Didn't find a line matching /match_data2mapping/ in the maq output file '$output_filename'");
    return;
}


# Find other successful executions working on the same data and link to it.
# Returns undef if there is no other data suitable to link to, and we should 
# do it the long way.  Returns 1 if the linking was successful. 0 if we tried
# but there were problems
#
# $type is either 'unique' or 'duplicate'
sub _check_for_shortcut {
    my($self,$type) = @_;

    my $model = $self->model;

    $DB::single = 1;
    my @params = (
        sample_name => $model->sample_name,
        reference_sequence_name => $model->reference_sequence_name,
        read_aligner_name => $model->read_aligner_name,
        dna_type => $model->dna_type,
        genome_model_id => { operator => 'ne', value => $model->genome_model_id},
    );
    #Someone left this from testing I guess;
    #print Data::Dumper::Dumper(\@params);
    #exit;
    my @similar_models = Genome::Model->get(@params);
    my @similar_model_ids = map { $_->genome_model_id } @similar_models;
    return unless (@similar_model_ids);
    my @possible_events = Genome::Model::Event->get(event_type => $self->event_type,
                                                    genome_model_event_id => {
                                                        operator => '!=',
                                                        value => $self->genome_model_event_id
                                                    },
                                                    event_status => ['Succeeded', 'Running'],
                                                    model_id => \@similar_model_ids,
                                                    run_id => $self->run_id,
                                                );

    foreach my $prior_event ( @possible_events ) {
        my $prior_model = Genome::Model->get(genome_model_id => $prior_event->model_id);
        # Do our model and the candidate model have the same number of sub-references?
        if (scalar($prior_model->get_subreference_names) != scalar($model->get_subreference_names)) {
            next;
        }

        # The bfq file is one of the first things created when align-reads is running, so
        # that's what we're testing for
        my $bfq_file_method = sprintf('%s_bfq_file_for_lane', $type);
        my $prior_bfq_file = $prior_event->$bfq_file_method;
        if (-f $prior_bfq_file) {
            # This is a good candidate to make symlinks to.  Note that the event we're linking to
            # may still be Running, in which case the target of these symlinks may not
            # exist yet.  We'll block at the end of execute() until they're done

            #Jim TODO - replace alignment_submaps_dir_for_lane
            #with the new and improved SOME_METHOD from EventWithReadSet.pm
            my $prior_alignments_dir = $prior_event->alignment_submaps_dir_for_lane;
            my @prior_alignment_files = map { sprintf("%s/%s_%s.map",$prior_alignments_dir,$_,$type) } 
                                        grep { $_ ne "all_sequences" }
                                        $prior_model->get_subreference_names(reference_extension=>'bfa');

            return 0 if (@prior_alignment_files == 0);  # The prior run didn't make the files we needed

            # Find the aligner output files
            my $unaligned_reads_file_method = sprintf('unaligned_%s_reads_file_for_lane',$type);
            my $prior_unaligned_reads_file = $prior_event->$unaligned_reads_file_method;
            my $this_unaligned_reads_file = $self->$unaligned_reads_file_method;
            symlink($prior_unaligned_reads_file, $this_unaligned_reads_file);

            # the bfq file
            #my $bfq_file_method = sprintf('%s_bfq_file_for_lane', $type);
            #my $prior_bfq_file = $prior_event->$bfq_file_method;
            my $this_bfq_file = $self->$bfq_file_method;
            symlink($prior_bfq_file, $this_bfq_file);

            # maq's output file
            my $output_file_method = sprintf('aligner_%s_output_file_for_lane',$type);
            my $prior_output_file = $prior_event->$output_file_method;
            my $this_output_file = $self->$output_file_method;
            symlink($prior_output_file, $this_output_file);

            my $this_alignments_dir = $self->alignment_submaps_dir_for_lane;
            mkdir $this_alignments_dir;

            foreach my $orig_file ( @prior_alignment_files ) {
                my($this_filename) = ($orig_file =~ m/.*\/(\S+?)$/);
                symlink($orig_file, $this_alignments_dir . '/' . $this_filename);
            }
            return $prior_event;
        }
    }

    return undef;
}



1;

