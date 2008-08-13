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

sub read_set_alignment_files_for_refseq {
    # this returns the above, or will return the old-style split maps
    my $self = shift;
    my $ref_seq_id = shift;
    my $event_id = $self->id;

    my $alignment_dir = $self->read_set_alignment_directory;

    # Look for files in the new format: $refseqid.map.$eventid
    my @files = grep { $_ and -e $_ } (
        glob($alignment_dir . "/$ref_seq_id.map.*")
    );
    return @files if (@files);

    # Now try the old format: $refseqid_{unique,duplicate}.map.$eventid
    my $glob_pattern = sprintf('%s/%s_*.map.*', $alignment_dir, $ref_seq_id);
    @files = grep { $_ and -e $_ } (
        glob($glob_pattern)
    );
    return @files;
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

    if ($read_set->is_paired_end) {
        die "not configured to handle PAIRED END data"
    }

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

# A hack replacement method for event.pm's method... it is a paste except 
# doesnt use timestamps as they were causing sol2sanger issues
sub base_temp_directory {
    my $self = shift;
    return $self->{base_temp_directory} if $self->{base_temp_directory};
    
    my $id = $self->id;
    
    my $event_type = $self->event_type;
    my ($base) = ($event_type =~ /([^\s]+) [^\s]+$/);
    
    my $dir = "/tmp/gm-$base-$id-XXXX";
    $dir =~ s/ /-/g;
    $dir = File::Temp::tempdir($dir, CLEANUP => 1);
    $self->{base_temp_directory} = $dir;
    $self->create_directory($dir);
    
    return $dir;
}


sub execute {
    my $self = shift;
    
$DB::single = $DB::stopper;

    my $model = $self->model;
    my $seq_dedup = $model->is_eliminate_all_duplicates;
    
    # prepare the reads
    my $read_set = $self->read_set;
    my $bfq_pathname = $self->prepare_input($read_set,$seq_dedup);
    
    # gather parameters
    my $event_id = $self->id;
    my $alignment_file = $self->create_temp_file_path("all.map");
    my $aligner_output_file = $self->aligner_output_file;
    my $unaligned_reads_file = $self->unaligned_reads_file;
    
    my $aligner_path = $self->aligner_path('read_aligner_name');
    my $aligner_params = $model->read_aligner_params || '';
    
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
    $aligner_params = join(' ', $aligner_params, '-d', $adaptor_file);
    
    # prepare the refseq
    my $ref_seq_path =  $model->reference_sequence_path;    
    my $ref_seq_file =  $ref_seq_path . "/all_sequences.bfa";
    unless (-e $ref_seq_file) {
        $self->error_message(sprintf("reference sequence file %s does not exist.  please verify this first.", $ref_seq_file));
        return;
    }
    my @subsequences = grep {$_ ne "all_sequences"} $model->get_subreference_names(reference_extension=>'bfa');
    

    # prepare paths for the results
    my $read_set_alignment_directory = $self->read_set_alignment_directory;
    if (-d $read_set_alignment_directory) {
        $self->status_message("found existing run directory $read_set_alignment_directory");
        my $errors;
        my @cross_refseq_alignment_files;
        for my $ref_seq_id (@subsequences) {
            my @alignment_files = $self->read_set_alignment_files_for_refseq($ref_seq_id);
            my @distinct = grep { /unique|distinct/ } @alignment_files;
            my @duplicate = grep { /duplicate|redu/ } @alignment_files;
            my @all = grep { /all/ } @alignment_files;
            my @other = grep { /other/ } @alignment_files;
            my @map = grep { /map/ } @alignment_files;

            push @cross_refseq_alignment_files, @alignment_files;
            
            # this is causing the PPAV orang model (flow cell 14545)to fail....we don't expect it to have all, distinct, or duplicate
            # it is also unclear how the 14545 flow cell directory differs from the 209N1 of the 14487 dirs
            # we could also use an elseif that looks for "other"...but there is still a hole where there are just submaps for specific
            # chromosomes

            if (@all) {
                $self->status_message("ref seq $ref_seq_id has complete map files");
            }
            elsif (@distinct and @duplicate) { 
                $self->status_message("ref seq $ref_seq_id has distinct and duplicate map files");
            }
            elsif (@other){
                $self->status_message("ref seq $ref_seq_id has an other map file");
            }
            elsif (@map){
                $self->status_message("ref seq $ref_seq_id has some map file");
                foreach my $map (@map){
                    unless (-s $map) {
                        $errors++;
                        $self->error_message("ref seq $ref_seq_id has zero size map file");
                    }
                }
            }
            else {
                $errors++;
                $self->error_message("ref seq $ref_seq_id has bad read set directory:\n\t" . join("\n\t",@alignment_files));
            }
        }
        unless (-s $unaligned_reads_file) {
            $self->error_message("missing unaligned reads file");
            ## this test is not finding unaligned files that are actually there....commenting out for now
            ##$errors++;
        }
        unless (-s $aligner_output_file) {
            $self->error_message("missing aligner output file");
            ## this test is not finding aligner output files that are actually there....commenting out for now
            ##$errors++;
        }
        if ($errors) {
            if (@cross_refseq_alignment_files) {
                $self->error_message("REFUSING TO CONTINUE with partial map files in place in old directory.");
                return;
            }
            else {
                $self->warning_message("RE-PROCESSING: Moving old directory out of the way");
                unless (rename ($read_set_alignment_directory,$read_set_alignment_directory . ".old.$$")) {
                    die "Failed to move old alignment directory out of the way: $!";
                }
                # fall through to the regular processing and try this again...
            }
        }
        else {
            $self->status_message("SHORTCUT SUCCESS: alignment data is already present.");
            return 1;
        }
    }
    $self->create_directory($read_set_alignment_directory);
    
    unless (-e $adaptor_file) {
        $self->error_message("Adaptor file $adaptor_file not found!: $!");
        return;
    }
    
    # prepare the alignment command
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

    my $line=`/gscmnt/sata114/info/medseq/pkg/maq/branches/lh3/maq-xp/maq-xp pileup -t $aligner_output_file 2>&1`;
    my ($evenness)=($line=~/(\S+)\%$/);

    $self->add_metric(
        name => 'evenness',
        value => $evenness
    );

$DB::single = $DB::stopper;

    # break up the alignments by the sequence they match, if necessary
    my $map_split = Genome::Model::Tools::Maq::MapSplit->execute(
                                                                 map_file => $alignment_file,
                                                                 submap_directory => $self->read_set_alignment_directory,
                                                                 reference_names => \@subsequences,
                                                             );
    unless($map_split) {
        $self->error_message("Failed to run map split on alignment file $alignment_file");
        return;
    }
    
    # these will match the wildcard which pulls old and new alignment files
    my @split_files = $map_split->output_files;
    for my $output_file (@split_files) {
        my $new_file_path = $output_file .'.'. $self->id;
        unless (rename($output_file,$new_file_path)) {
            $self->error_message("Failed to rename file '$output_file' => '$new_file_path'");
            return;
        }
    }
    
    my $errors;
    for my $subsequence (@subsequences) {
        my @found = $self->read_set_alignment_files_for_refseq($subsequence);
        unless (@found) {
            $self->error_message("Failed to find map file for $subsequence!");
            $errors++;
        }
    }
    if ($errors) {
        my @files = glob($self->read_set_alignment_directory . '/*');
        $self->error_message("Files in dir are:\n\t" . join("\n\t",@files) . "\n");
        return;
    }
    
    $self->generate_metric($self->metrics_for_class);

    return 1;
}

sub verify_successful_completion {
    my ($self) = @_;
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

1;

