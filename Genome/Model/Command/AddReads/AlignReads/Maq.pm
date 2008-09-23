package Genome::Model::Command::AddReads::AlignReads::Maq;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;
use Genome::Model::Command::AddReads::AlignReads;
use Genome::Model::ReadSet;

class Genome::Model::Command::AddReads::AlignReads::Maq {
    is => [
        'Genome::Model::Command::AddReads::AlignReads',
        'Genome::Model::Command::MaqSubclasser'
    ],
    has => [
    read_set      => { is => 'Genome::RunChunk', id_by => 'run_id' },
    read_set_link => { is => 'Genome::Model::ReadSet', id_by => ['model_id','run_id'] },
    read_set_alignment_directory => { via => 'read_set_link' },
    run_subset_name => { via => 'read_set' }, 
    _alignment_file_paths_unsubmapped => {
        doc => "the paths to to the map files before submapping (not always available)",
        calculate => q|
        return unless -d $read_set_directory;;
        return grep { -e $_ } glob("${read_set_directory}/*${run_subset_name}.map");
        |,
        calculate_from => ['read_set_directory','run_subset_name'],
    },
    subsequences => {
        doc => "the sub-sequence names with out 'all_sequences'",
        calculate_from => ['model'],
        calculate => q|
        return grep {$_ ne "all_sequences"} $model->get_subreference_names(reference_extension=>'bfa');
        |,
    },
    is_eliminate_all_duplicates => { via => 'model' },
    _calculate_total_read_count => { via => 'read_set_link'},
    output_data_dir => {
        doc => "The path at which the model stores all of its private data for a given run",
        calculate_from => ['read_set_directory'],
        calculate => q|
        return $read_set_directory
        |,
        is_constant => 1,
        is_deprecated => 1,
    },
    input_read_file_path => {
        is_transient=>1,
        is_optional=>1,
        doc => "temp storage for the fake filename for the metrics to calculate later",

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
    my $read_set = $self->read_set_link;
    my $alignment_dir = $read_set->read_set_alignment_directory;

    # Look for files in the new format: $refseqid.map.$eventid
    my @files = grep { $_ and -e $_ } (
        glob($read_set->read_set_alignment_directory . "/$ref_seq_id.map.*") #bkward compat
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
    my $lane = $self->read_set_link->subset_name;
    my $file = $self->read_set_link->read_set_alignment_directory . "/alignments_lane_${lane}.map.$event_id";
    $file =~ s/\.map\./\.map.aligner_output\./g;
    return $file;
}

sub unaligned_reads_file {
    my $self = shift;
    my $event_id = $self->id;
    my $read_set = $self->read_set_link;
    my $lane = $read_set->subset_name;
    return $read_set->read_set_alignment_directory . "/s_${lane}_sequence.unaligned.$event_id";
}

sub unaligned_reads_files {
    my $self = shift;
    #my $event_id = $self->id;
    my $read_set = $self->read_set_link;
    my $lane = $read_set->subset_name;
    my @unaligned_reads_files = glob ($read_set->read_set_alignment_directory . "/${lane}_sequence.unaligned.*");
    return @unaligned_reads_files;
    #return $self->read_set_alignment_directory . "/s_${lane}_sequence.unaligned.$event_id";
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

        if (defined $self->read_set_link->unique_reads_across_library && defined $self->read_set_link->duplicate_reads_across_library) {
            $total_reads_passed_quality_filter_count = ($self->read_set_link->unique_reads_across_library + $self->read_set_link->duplicate_reads_across_library);
        }
        unless ($total_reads_passed_quality_filter_count) {
            my @f = grep {-f $_ } $self->input_read_file_path;
            unless (@f) {
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

    my $total_bases_passed_quality_filter_count = $self->total_reads_passed_quality_filter_count * $self->read_set_link->read_length;
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
    for my $f ($self->read_set_link->poorly_aligned_reads_list_paths) {
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

    my @f = $self->read_set_link->aligner_output_file_paths;
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

    my $aligned_base_pair_count = $self->aligned_read_count * $self->read_set_link->read_length;
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
    my $unaligned_base_pair_count = $self->unaligned_read_count * $self->read_set_link->read_length;
    return $unaligned_base_pair_count;
}

sub total_base_pair_count {
    my $self = shift;
    return $self->get_metric_value('total_base_pair_count');
}

sub _calculate_total_base_pair_count {
    my $self = shift;

    my $total_base_pair_count = $self->total_read_count * $self->read_set_link->read_length;
    return $total_base_pair_count;
}

sub prepare_input {
    my ($self, $read_set, $seq_dedup) = @_;

    #if ($read_set->is_paired_end) {
    #    die "not configured to handle PAIRED END data"
    #}

    my $lane = $self->read_set_link->subset_name;
    my $read_set_desc = $read_set->full_name . "(" . $read_set->id . ")";
    my $gerald_directory = $read_set->_run_lane_solexa->gerald_directory;
    unless ($gerald_directory) {
        die "No gerald directory in the database for or $read_set_desc"
    }
    unless (-d $gerald_directory) {
        die "No gerald directory on the filesystem for $read_set_desc: $gerald_directory";
    }
    my @solexa_output_paths;
    if($read_set->is_paired_end) {

        push @solexa_output_paths, "$gerald_directory/s_${lane}_2_sequence.txt";
        push @solexa_output_paths, "$gerald_directory/s_${lane}_1_sequence.txt";
    }
    else 
    {
        push @solexa_output_paths, "$gerald_directory/s_${lane}_sequence.txt";
    }
    #i deleted soemthing to inputfile paths here 
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

    my @bfq_pathnames;
    my $counter=0;
    for my $solexa_output_path (@solexa_output_paths) {
        unless ($fastq_pathname) {
            $fastq_pathname = $self->create_temp_file_path('fastq' . $counter);
            $self->shellcmd(
                cmd => "$aligner_path sol2sanger $solexa_output_path $fastq_pathname",
                input_files => [$solexa_output_path],
                output_files => [$fastq_pathname],
                skip_if_output_is_present => 1,
            );
        }

        # create a bfq
        my $bfq_pathname = $self->create_temp_file_path('bfq' . $counter);
        unless ($bfq_pathname) {
            die "Failed to create temp file for bfq!";
        }

        $self->shellcmd(
            cmd => "$aligner_path fastq2bfq $fastq_pathname $bfq_pathname",
            input_files => [$fastq_pathname],
            output_files => [$bfq_pathname],
            skip_if_output_is_present => 1,
        );
        push @bfq_pathnames, $bfq_pathname;
        $counter++;
    }
    return @bfq_pathnames;
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
    # prepare the reads
    my @bfq_pathnames = $self->prepare_input($self->read_set,$self->is_eliminate_all_duplicates);

    # prepare the refseq
    my $ref_seq_path =  $model->reference_sequence_path;
    my $ref_seq_file =  $ref_seq_path . "/all_sequences.bfa";
    unless (-e $ref_seq_file) {
        $self->error_message(sprintf("reference sequence file %s does not exist.  please verify this first.", $ref_seq_file));
        return;
    }

    # prepare paths for the results

    if ($self->alignment_data_available_and_correct) {
        $self->status_message("existing alignment data is available and deemed correct");
        return 1;
    }

    my $read_set_alignment_directory = $self->read_set_link->read_set_alignment_directory;
    $self->create_directory($read_set_alignment_directory);

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
    unless (-e $adaptor_file) {
        $self->error_message("Adaptor file $adaptor_file not found!: $!");
        return;
    }

    # gather parameters
    my $event_id = $self->id;
    my $alignment_file = $self->create_temp_file_path("all.map");
    my $aligner_output_file = $self->aligner_output_file;
    my $unaligned_reads_file = $self->unaligned_reads_file;
    
    # prepare the alignment command
    my $cmdline = 
        $aligner_path
        . sprintf(' map %s -u %s %s %s %s %s > ',
                          $aligner_params,
                          $unaligned_reads_file,
                          $alignment_file,
                          $ref_seq_file,
                          @bfq_pathnames) 
        . $aligner_output_file 
        . ' 2>&1';

    # run the aligner
    $self->shellcmd(
        cmd                         => $cmdline,
        input_files                 => [$ref_seq_file, @bfq_pathnames],
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
    

    my @subsequences = $self->subsequences;
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
    my $read_set_link=Genome::Model::ReadSet->get(model_id=>$self->model_id, read_set_id=> $self->run_id);
    $read_set_link->first_build_id($self->parent_event_id);
    
    return 1;
}

sub verify_successful_completion {
    my ($self) = @_;
    return 1;
}

sub alignment_data_available_and_correct {
    my $self = shift;

    my $read_set_alignment_directory = $self->read_set_alignment_directory;
    if (-d $read_set_alignment_directory) {
        $self->status_message("found existing run directory $read_set_alignment_directory");
    } else {
        return;
    }
    my $errors = 0;
    my @cross_refseq_alignment_files;
    for my $ref_seq_id ($self->subsequences) {
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
        } elsif (@distinct and @duplicate) { 
            $self->status_message("ref seq $ref_seq_id has distinct and duplicate map files");
        } elsif (@other){
            $self->status_message("ref seq $ref_seq_id has an other map file");
        } elsif (@map){
            $self->status_message("ref seq $ref_seq_id has some map file");
            foreach my $map (@map){
                unless (-s $map) {
                    $errors++;
                    $self->error_message("ref seq $ref_seq_id has zero size map file '$map'");
                }
            }
        } else {
            $errors++;
            $self->error_message("ref seq $ref_seq_id has bad read set directory:". join("\n\t",@alignment_files));
        }
    }
    my $unaligned_reads_file = $self->unaligned_reads_file;
    $unaligned_reads_file =~ s/\.\d+$/\*/;
    my @possible_unaligned_shortcuts= glob($unaligned_reads_file);
    
    # the addition of the above glob prevents entrance into the if part of this loop in any situation that I can imagine
    for my $possible_shortcut (@possible_unaligned_shortcuts) {
        my $found_unaligned_reads_file = $self->check_for_existence($possible_shortcut);
        if (!$found_unaligned_reads_file) {
            $self->error_message("missing unaligned reads file base '$possible_shortcut'");
            $errors++;
        } elsif (!-s $possible_shortcut) {
            $self->error_message("unaligned reads file '$possible_shortcut' found but zero size");
            $errors++;
        }
    }
    my $aligner_output_file = $self->aligner_output_file;
    $aligner_output_file =~ s/\.\d+$/\*/;
    my @possible_aligner_output_shortcuts = glob ($aligner_output_file);

    for my $possible_shortcut (@possible_aligner_output_shortcuts) {
        my $found_aligner_output_file = $self->check_for_existence($possible_shortcut);
        if (!$found_aligner_output_file) {
            $self->error_message("missing aligner output file base '$possible_shortcut'");
            $errors++;
        } elsif (!$self->_check_maq_successful_completion($possible_shortcut)) {
            $self->error_message("aligner output file '$possible_shortcut' found, but incomplete");
            $errors++;
        }
    }    
    if ($errors) {
        if (@cross_refseq_alignment_files) {
            die("REFUSING TO CONTINUE with partial map files in place in old directory.");
        }
        else {
            $self->warning_message("RE-PROCESSING: Moving old directory out of the way");
            unless (rename ($read_set_alignment_directory,$read_set_alignment_directory . ".old.$$")) {
                die("Failed to move old alignment directory out of the way: $!");
            }
            return;
        }
    } else {
        $self->status_message("SHORTCUT SUCCESS: alignment data is already present.");
        return 1;
    }
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

