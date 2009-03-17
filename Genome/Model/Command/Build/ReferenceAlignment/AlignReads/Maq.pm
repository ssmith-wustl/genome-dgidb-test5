package Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Maq;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;
use Genome::Model::Command::Build::ReferenceAlignment::AlignReads;

class Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Maq {
    is => [
        'Genome::Model::Command::Build::ReferenceAlignment::AlignReads',
    ],
    has => [
            _calculate_total_read_count => { via => 'instrument_data'},
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

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=12000]' -M 1610612736";
}



# maq map file for all this lane's alignments

sub read_set_alignment_files_for_refseq {
    # this returns the above, or will return the old-style split maps
    my $self = shift;
    my $ref_seq_id = shift;
    my $event_id = $self->id;
    my $read_set = $self->instrument_data_assignment;
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
    my $lane = $self->instrument_data_assignment->subset_name;
    my $file = $self->instrument_data_assignment->read_set_alignment_directory . "/alignments_lane_${lane}.map.$event_id";
    $file =~ s/\.map\./\.map.aligner_output\./g;
    return $file;
}

#added this method to only return the unqualified name of the file
sub aligner_output_file_name {
    my $self = shift;
    my $event_id = $self->id;
    my $lane = $self->instrument_data_assignment->subset_name;
    my $file = "/alignments_lane_${lane}.map.$event_id";
    $file =~ s/\.map\./\.map.aligner_output\./g;
    return $file;
}

#added this method to only return the unqualified name of the file
sub unaligned_reads_file_name {
    my $self = shift;
    my $event_id = $self->id;
    my $read_set = $self->instrument_data_assignment;
    my $lane = $read_set->subset_name;
    return "/s_${lane}_sequence.unaligned.$event_id";
}

sub unaligned_reads_file {
    my $self = shift;
    my $event_id = $self->id;
    my $read_set = $self->instrument_data_assignment;
    my $lane = $read_set->subset_name;
    return $read_set->read_set_alignment_directory . "/s_${lane}_sequence.unaligned.$event_id";
}

sub unaligned_reads_files {
    my $self = shift;
    #my $event_id = $self->id;
    my $read_set = $self->instrument_data_assignment;
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

        if (defined $self->instrument_data_assignment->unique_reads_across_library && defined $self->instrument_data_assignment->duplicate_reads_across_library) {
            $total_reads_passed_quality_filter_count = ($self->instrument_data_assignment->unique_reads_across_library + $self->instrument_data_assignment->duplicate_reads_across_library);
        }
        unless ($total_reads_passed_quality_filter_count) {
            my @f = grep {-f $_ } $self->instrument_data->bfq_filenames;
            unless (@f) {
                $self->error_message("Problem calculating metric...this doesn't mean the step failed");
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

    # total_reads_passed_quality_filter_count might return "Not Found"
    no warnings 'numeric';
    my $total_bases_passed_quality_filter_count = $self->total_reads_passed_quality_filter_count * $self->instrument_data_assignment->read_length;
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
    for my $f ($self->instrument_data_assignment->poorly_aligned_reads_list_paths) {
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

    my @f = $self->instrument_data_assignment->aligner_output_file_paths;
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
    no warnings 'numeric';
    # total_reads_passed_quality_filter_count might return "Not Found"
    my $aligned_read_count = $self->total_reads_passed_quality_filter_count - $self->poorly_aligned_read_count - $self->contaminated_read_count;
    return $aligned_read_count;
}

sub aligned_base_pair_count {
    my $self = shift;
    return $self->get_metric_value('aligned_base_pair_count');
}

sub _calculate_aligned_base_pair_count {
    my $self = shift;

    my $aligned_base_pair_count = $self->aligned_read_count * $self->instrument_data_assignment->read_length;
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
    my $unaligned_base_pair_count = $self->unaligned_read_count * $self->instrument_data_assignment->read_length;
    return $unaligned_base_pair_count;
}

sub total_base_pair_count {
    my $self = shift;
    return $self->get_metric_value('total_base_pair_count');
}

sub _calculate_total_base_pair_count {
    my $self = shift;

    my $total_base_pair_count = $self->total_read_count * $self->instrument_data_assignment->read_length;
    return $total_base_pair_count;
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
    
    # undo any changes from a prior run
    $self->revert;

    # extract params to run the alignment
    # from the model
    my $model = $self->model;
    my $aligner_name    = $model->read_aligner_name;
    my $aligner_version = $model->read_aligner_version;
    if ($aligner_name =~ /^(maq)(\d_\d_\d)$/) {
        $aligner_name = $1;
        unless ($aligner_version) {
            $aligner_version = $2;
            $aligner_version =~ s/_/\./g;
        }
    }
    my $aligner_params  = $model->read_aligner_params;
    my $reference_build = $model->reference_build;

    # extract the data to align from this event's params
    my $instrument_data = $self->instrument_data;

    # ensure the alignments are present
    my $alignment_dir = $instrument_data->find_or_generate_alignments_dir(
        aligner_name    => $aligner_name,
        version         => $aligner_version,
        params          => $aligner_params,
        reference_build => $reference_build,
        event           => $self,                       # for logging
    );

    unless ($alignment_dir and -d $alignment_dir) {
        if ($alignment_dir) {
            $self->error_message("Missing alignment directory '$alignment_dir'!");
        }
        $self->error_message("Error generating alignments!:\n" .  join("\n",$instrument_data->error_message));
        return;
    }

    my $instrument_data_assignment = $self->instrument_data_assignment;
    unless($instrument_data_assignment->first_build_id) {
        $instrument_data_assignment->first_build_id($self->build_id);
    }

    $self->generate_metric($self->metrics_for_class);

    # the hard way to get one value...

    my $evenness_path = $alignment_dir . '/evenness';
    if (-s $evenness_path) {
    	my $evenness = IO::File->new($evenness_path)->getline;
    	chomp $evenness;
    	$self->add_metric(
        	name => 'evenness',
        	value => $evenness
    	);
    }
 
    unless ($self->verify_successful_completion) {
        $self->error_message("Error verifying completion!");
        return;
    }

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
            $self->status_message("Unable to shortcut this alignment(we haven't done it before):ref seq $ref_seq_id has bad read set directory:". join("\n\t",@alignment_files));
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
            $self->status_message("(shortcutting problem...this is not a fatal error, do not panic: missing aligner output file base '$possible_shortcut'");
            $errors++;
        } elsif (!$self->_check_maq_successful_completion($possible_shortcut)) {
            $self->status_message("shortcutting problem...this isn't fatal, don't panic.  aligner output file '$possible_shortcut' found, but incomplete");
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
        if (m/\[match_index_sorted\] no reasonable reads are available. Exit!/) {
            $aligner_output_fh->close();
            return 1;
        }
    }

    $self->status_message("Alignment shortcut failure(we can't cheat, but this doesn't mean its broken):  Didn't find a line matching /match_data2mapping/ in the maq output file '$output_filename', and did not find the 'no reasonable reads are available' line either.");
    return;
}

1;

