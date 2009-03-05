
package Genome::InstrumentData::Command::Align::Maq;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::Align::Maq {
    is => ['Genome::Utility::FileSystem', 'Command'],
    has_input => [
        instrument_data                 => {
                                            is => 'Genome::InstrumentData',
                                            id_by => 'instrument_data_id'
                                        },
        instrument_data_id              => {
                                            is => 'Number',
                                            doc => 'the local database id of the instrument data (reads) to align'
                                        },
        event                           => {
                                            is => 'Genome::Model::Event', id_by => 'event_id', 
                                            doc => 'handles logging, and will eventually not be required'
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
        adaptor_flag                  => {
                                          is => 'Text',
                                          doc => 'a flag for the adaptor to use in alignment(dna or rna)',
                                        },
        version                         => {
                                            is => 'Text', default_value => '0.7.1',
                                            doc => 'the version of maq to use, i.e. 0.6.8, 0.7.1, etc.'
                                        },
        params                          => {
                                            is => 'Text', default_value => '', 
                                            doc => 'any additional params for the aligner in a single string'
                                        },
        check_only                      => {
                                            is => 'Boolean',
                                            doc => 'do not run alignments, just check to see if they are present/running'
                                        },
    ],
    has_constant => [
        aligner_name                    => { value => 'maq' },
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

sub execute {
    my $self = shift;

    # inputs and params for the alignment are on the object
    my $instrument_data = $self->instrument_data;
    my $reference_build = $self->reference_build;
    my $aligner_version = $self->version;
    my $aligner_params  = $self->params;

    # for now filesystem activity and logging go to an event which is passed-in
    my $event = $self->event;
    my $fsmgr = $event;
    my $logger = $event;
    my $generator_id = $event->genome_model_event_id;

    # we resolve these first, since we might just print the paths we work with then exit
    my @input_pathnames = $instrument_data->bfq_filenames;
    $logger->status_message("INPUT PATHS: @input_pathnames\n");

    # prepare the refseq
    my $ref_seq_path =  $reference_build->data_directory;
    my $ref_seq_file =  $reference_build->full_consensus_path('bfa');
    unless (-e $ref_seq_file) {
        $logger->error_message(sprintf("reference sequence file %s does not exist.  please verify this first.", $ref_seq_file));
        return;
    }
    $logger->status_message("REFSEQ PATH: $ref_seq_file\n");

    # the directory for results is constant given our parameters
    my $results_dir = $self->results_dir;
    $logger->status_message("OUTPUT PATH: $results_dir\n");

    # check the status of this data set
    # be sure the check is atomic...
    my $resource_lock_name = $results_dir . '.generate';
    my $lock = $self->lock_resource(resource_lock => $resource_lock_name, max_try => 2);
    unless ($lock) {
        $logger->status_message("This data set is still being processed by its creator.  Waiting for lock...");
        $lock = $self->lock_resource(resource_lock => $resource_lock_name);
        unless ($lock) {
            $logger->error_message("Failed to get lock!");
            return;
        }
    }
    if ($self->alignment_data_available_and_correct($results_dir)) {
        $logger->status_message("Existing alignment data is available and deemed correct.");
        $self->unlock_resource(resource_lock => $lock);
        return 1;
    }
    $logger->status_message("No previous alignment data at $results_dir.");
    if ($self->check_only) {
        # check for the data only, do not process
        $self->unlock_resource(resource_lock => $resource_lock_name);
        return 1;
    }
    $logger->status_message("No alignment files found...beginning processing and setting marker to prevent simultaneous processing.");

    my $aligner_output_file;
    # do this in an eval block so we can unlock the resource cleanly when we finish
    my $retval = eval {

        # the base directory for results
        $fsmgr->create_directory($results_dir);

        # this was the old lock file
        $fsmgr->create_file("Processing Marker", $results_dir . "/processing");

        # these are standard constant values set by the structure of the output directory
        my $lane = $instrument_data->subset_name;

        my $aligner_output_file_name = "/alignments_lane_${lane}.map.$generator_id";
        $aligner_output_file_name =~ s/\.map\./\.map.aligner_output\./g;
        $aligner_output_file = $results_dir . $aligner_output_file_name;

        my $unaligned_reads_file_name = "/s_${lane}_sequence.unaligned.$generator_id";
        my $unaligned_reads_file = $results_dir . $unaligned_reads_file_name;

        # resolve adaptor file
        # TODO: get fresh from LIMS
        unless ($self->adaptor_flag) {
            my @dna = GSC::DNA->get(dna_name => $instrument_data->sample_name);
            if (@dna == 1) {
                if ($dna[0]->dna_type eq 'genomic dna') {
                    $self->adaptor_flag('dna');
                } elsif ($dna[0]->dna_type eq 'rna') {
                    $self->adaptor_flag('rna');
                }
            }
        }
        unless (defined($self->adaptor_flag)) {
            $logger->error_message("Adaptor not defined.");
            return;
        }

        ###input/output files
        my $alignment_file = $fsmgr->create_temp_file_path("all.map");  

        ###upper bound insert param
        my $upper_bound_on_insert_size;
        if ($instrument_data->is_paired_end) {
            my $sd_above = $instrument_data->sd_above_insert_size;
            my $median_insert = $instrument_data->median_insert_size;
            $upper_bound_on_insert_size= ($sd_above * 5) + $median_insert;
            unless($upper_bound_on_insert_size > 0) {
                $logger->status_message("Unable to calculate a valid insert size to run maq with. Using 600 (hax)");
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
            use_version             => $aligner_version,
            align_options           => $aligner_params,
            dna_type                => $self->adaptor_flag,
            alignment_file          => $alignment_file,
            aligner_output_file     => $aligner_output_file,
            unaligned_reads_file    => $unaligned_reads_file,
            upper_bound             => $upper_bound_on_insert_size,
        );
        $logger->status_message("Alignment params:\n" . Data::Dumper::Dumper(\%params));
        
        $logger->status_message("Executing aligner...");
        my $alignments = Genome::Model::Tools::Maq::AlignReads->execute(%params);
        $logger->status_message("Aligner executed.");
        
        ##############################################
    
        # in some cases maq will "work" but not make an unaligned reads file
        # this happens when all reads are filtered out
        # make an empty file to represent our zero-item list of unaligned reads
        unless (-e $unaligned_reads_file) {
            if (my $fh = IO::File->new(">".$unaligned_reads_file)) {
                $logger->status_message("Made empty unaligned reads file since that file is was not generated by maq.");
            } else {
                $logger->error_message("Failed to make empty unaligned reads file!: $!");
            }
        }

        my $line=`/gscmnt/sata114/info/medseq/pkg/maq/branches/lh3/maq-xp/maq-xp pileup -t $aligner_output_file 2>&1`;
        my ($evenness)=($line=~/(\S+)\%$/);
        IO::File->new(">$results_dir/evenness")->print($evenness);
    
        $DB::single = $DB::stopper;
        
        my @subsequences = grep {$_ ne "all_sequences"} $reference_build->subreference_names(reference_extension=>'bfa');
        
        # break up the alignments by the sequence they match, if necessary
        # my $map_split = Genome::Model::Tools::Maq::MapSplit->execute(
        #   map_file => $alignment_file,
        #   submap_directory => $self->results_dir,
        #   reference_names => \@subsequences,
        # );
        my $mapsplit_cmd = Genome::Model::Tools::Maq->path_for_mapsplit_version($aligner_version);
        my $ok_failure_flag=0;
        if (@subsequences) {
            my $cmd = "$mapsplit_cmd " . $self->results_dir . "/ $alignment_file " . join(',',@subsequences);
            my $rv= system($cmd);
            if($rv) {
                #arbitrary convention set up with homemade mapsplit and mapsplit_long..return 2 if file is empty.
                if($rv/256 == 2) {
                    $logger->error_message("no reads in map.");
                    $ok_failure_flag=1;
                }
                else {
                    $logger->error_message("Failed to run map split on alignment file $alignment_file");
                    return;
                }
            }
        }
        else {
            @subsequences='all_sequences';
            my $copy_cmd = "cp $alignment_file " . $self->results_dir . "/all_sequences.map";
            my $copy_rv = system($copy_cmd);
            if ($copy_rv) {
                $logger->error_message('copy of all_sequences.map failed');
                die;
            }
        }

        # these will match the wildcard which pulls old and new alignment files
        # hacky: this still works even if no reads were in the map file, because one file will be touched before
        # mapsplit quits.
        my @split_files = glob($self->results_dir . "/*.map");
        for my $output_file (@split_files) {
            my $new_file_path = $output_file .'.'. $generator_id;
            unless (rename($output_file,$new_file_path)) {
                $logger->error_message("Failed to rename file '$output_file' => '$new_file_path'");
                return;
            }
        }

        my $errors;
        unless($ok_failure_flag) {
            for my $subsequence (@subsequences) {
                my @found = $self->results_files_for_refseq($subsequence);
                unless (@found) {
                    $logger->error_message("Failed to find map file for $subsequence!");
                    $errors++;
                }
            }
            if ($errors) {
                my @files = glob($self->results_dir . '/*');
                $logger->error_message("Files in dir are:\n\t" . join("\n\t",@files) . "\n");
                return;
            }
        }
        return 1;
    };

    if ($@ or !$retval) {
        my $exception = $@;
        rename $results_dir, $results_dir . ".bad$$";
        eval { $self->unlock_resource(resource_lock => $results_dir . '.generating'); };
        if ($exception) {
            die $exception;
        }
        else {
            return;
        }
    }

    unless ($self->_check_maq_successful_completion($aligner_output_file)) {
        $logger->error_message('Aligner output file incorrect after maq finished seemingly successfully');
        $self->unlock_resource(resource_lock => $resource_lock_name);
        return;
    }

    $self->unlock_resource(resource_lock => $resource_lock_name);
    return $retval;
}

sub results_dir {
    my $self = shift;

    my $aligner_name    = $self->aligner_name;
    my $aligner_version = $self->version;
    $aligner_version =~ s/\./_/g;
    my $aligner_label   = $aligner_name . $aligner_version;

    my $dir = $self->instrument_data->alignment_directory_for_aligner_and_refseq(
        $aligner_label,
        $self->reference_name
    );

    return $dir;
}

sub alignment_data_available_and_correct {
    my $self = shift;
    my $results_dir = $self->results_dir;

    my $instrument_data = $self->instrument_data;
    my $reference_build = $self->reference_build;
    my $logger          = $self->event;

    my @subsequences = grep { $_ ne 'all_sequences' } $reference_build->subreference_names;

    if (-d $results_dir) {
        $logger->status_message("found existing run directory $results_dir");
    } else {
        return;
    }

    my $errors = 0;
    my @cross_refseq_alignment_files;
    $logger->status_message("verifying reference sequences...");
    for my $ref_seq_id (@subsequences) {
        my @alignment_files = $self->results_files_for_refseq($ref_seq_id);
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
            $logger->status_message("  ref seq $ref_seq_id has complete map files");
        } elsif (@distinct and @duplicate) { 
            $logger->status_message("  ref seq $ref_seq_id has distinct and duplicate map files");
        } elsif (@other){
            $logger->status_message("  ref seq $ref_seq_id has an other map file");
        } elsif (@map){
            $logger->status_message("  ref seq $ref_seq_id has some map file");
            foreach my $map (@map){
                unless (-s $map) {
                    $errors++;
                    $logger->error_message("ref seq $ref_seq_id has zero size map file '$map'");
                }
            }
        } else {
            $errors++;
            $logger->status_message("Unable to shortcut this alignment(we haven't done it before):ref seq $ref_seq_id has bad read set directory:". join("\n\t",@alignment_files));
        }
    }

    my $lane = $self->instrument_data->subset_name;

    # THIS SEEMS BAD, it never actually tested for the existence of an unaligned file........
    #my $unaligned_reads_file_pattern = "/alignments_lane_${lane}.map.*";
    #$unaligned_reads_file_pattern =~ s/\.map\./\.map.aligner_output\./g;
    #$unaligned_reads_file_pattern =~ s/\.\d+$/\*/;
    my $unaligned_reads_file_pattern =    "/s_${lane}_sequence\.unaligned\.*";

    my @possible_unaligned_shortcuts= glob($unaligned_reads_file_pattern);

    # the addition of the above glob prevents entrance into the if part of this loop in any situation that I can imagine
    for my $possible_shortcut (@possible_unaligned_shortcuts) {
        my $found_unaligned_reads_file = $self->check_for_path_existence($possible_shortcut);
        if (!$found_unaligned_reads_file) {
            $logger->error_message("missing unaligned reads file base '$possible_shortcut'");
            $errors++;
        } elsif (!-s $possible_shortcut) {
            $logger->error_message("unaligned reads file '$possible_shortcut' found but zero size");
            $errors++;
        }
    }

    my $aligner_output_file_pattern = "/alignments_lane_${lane}.map.*";
    $aligner_output_file_pattern =~ s/\.map\./\.map.aligner_output\./g;
    my @possible_aligner_output_shortcuts = glob ($results_dir . $aligner_output_file_pattern);

    for my $possible_shortcut (@possible_aligner_output_shortcuts) {
        my $found_aligner_output_file = $self->check_for_path_existence($possible_shortcut);
        if (!$found_aligner_output_file) {
            $logger->status_message("this is not a fatal error, do not panic: missing aligner output file base '$possible_shortcut'");
            $errors++;
        } elsif (!$self->_check_maq_successful_completion($possible_shortcut)) {
            $logger->status_message("this isn't fatal, don't panic.  aligner output file '$possible_shortcut' found, but incomplete");
            $errors++;
        }
    }
    if ($errors) {
        if (@cross_refseq_alignment_files) {
            my $msg = 'REFUSING TO CONTINUE with partial map files in place in old directory:' ."\n";
            $msg .= join("\n",@cross_refseq_alignment_files) ."\n";
            die($msg);
        }
        else {
            $self->warning_message("RE-PROCESSING: Moving old directory out of the way");
            unless (rename ($results_dir,$results_dir . ".old.$$")) {
                die("Failed to move old alignment directory out of the way: $!");
            }
            return;
        }
    } else {
        $logger->status_message("SHORTCUT SUCCESS: alignment data is present and correct");
        return 1;
    }
}

sub results_files_for_refseq {
    # this returns the above, or will return the old-style split maps
    my $self = shift;
    my $ref_seq_id = shift;

    my $results_dir = $self->results_dir;

    # Look for files in the new format: $refseqid.map.$eventid
    my @files = grep { $_ and -e $_ } (
        glob($results_dir . "/$ref_seq_id.map.*") #bkward compat
    );
    return @files if (@files);

    # Now try the old format: $refseqid_{unique,duplicate}.map.$eventid
    my $glob_pattern = sprintf('%s/%s_*.map.*', $results_dir, $ref_seq_id);
    @files = grep { $_ and -e $_ } (
        glob($glob_pattern)
    );
    return @files;
}

sub _check_maq_successful_completion {
    my $self = shift;
    my $aligner_output_file = shift;

    unless ($aligner_output_file && -s $aligner_output_file) {
        $self->error_message("No aligner output file '$aligner_output_file' found or zero size.");
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
            $self->error_message($instrument_data->error_message);
            return;
        }
        if ($$stats{'isPE'} != 1) {
            $self->error_message('Paired-end read set was not aligned as paired end data.');
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

    $self->status_message("Alignment shortcut failure(we can't cheat, but this doesn't mean its broken):  Didn't find a line matching /match_data2mapping/ in the maq output file '$aligner_output_file', and did not find the 'no reasonable reads are available' line either.");
    return;
}

sub get_alignment_statistics {
    my $self = shift;
    my $aligner_output_file = shift;

    unless ($aligner_output_file && -s $aligner_output_file) {
        $self->error_message("No aligner output file '$aligner_output_file' found or zero size.");
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

1;
