package Genome::InstrumentData::Solexa;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::InstrumentData::Solexa {
    is => 'Genome::InstrumentData',
    has_constant => [
        sequencing_platform => { value => 'solexa' },
    ],
    has_optional => [
        project_name => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'project_name' ],
            is_mutable => 1,
        },
        target_region_set_name => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'target_region_set_name' ],
            is_mutable => 1,
        },
        flow_cell_id => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'flow_cell_id' ],
            is_mutable => 1,
        },
        # TODO Need to remove, depends on LIMS tables
        flow_cell => {
            is => 'Genome::InstrumentData::FlowCell',
            id_by => 'flow_cell_id',
        },
        lane => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'lane' ],
            is_mutable => 1,
        },
        read_length => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'read_length' ],
            is_mutable => 1,
        },
        filt_error_rate_avg => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'filt_error_rate_avg' ],
            is_mutable => 1,
        },
        rev_filt_error_rate_avg => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'rev_filt_error_rate_avg' ],
            is_mutable => 1,
        },
        fwd_filt_error_rate_avg => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'fwd_filt_error_rate_avg' ],
            is_mutable => 1,
        },
        rev_filt_aligned_clusters_pct => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'rev_filt_aligned_clusters_pct' ],
            is_mutable => 1,
        },
        fwd_filt_aligned_clusters_pct => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'fwd_filt_aligned_clusters_pct' ],
            is_mutable => 1,
        },
        rev_seq_id => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'rev_seq_id' ],
            is_mutable => 1,
        },
        fwd_seq_id => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'fwd_seq_id' ],
            is_mutable => 1,
        },
        rev_read_length => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'rev_read_length' ],
            is_mutable => 1,
        },
        fwd_read_length => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'fwd_read_length' ],
            is_mutable => 1,
        },
        rev_kilobases_read => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'rev_kilobases_read' ],
            is_mutable => 1,
        },
        fwd_kilobases_read => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'fwd_kilobases_read' ],
            is_mutable => 1,
        },
        rev_run_type => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'rev_run_type' ],
            is_mutable => 1,
        },
        fwd_run_type => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'fwd_run_type' ],
            is_mutable => 1,
        },
        run_type => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'run_type' ],
            is_mutable => 1,
        },
        gerald_directory => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'gerald_directory' ],
            is_mutable => 1,
        },
        median_insert_size => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'median_insert_size' ],
            is_mutable => 1,
        },
        sd_above_insert_size => { 
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'sd_above_insert_size' ],
            is_mutable => 1,
        },
        sd_below_insert_size => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'sd_below_insert_size' ],
            is_mutable => 1,
        },
        is_external => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'is_external' ],
            is_mutable => 1,
        },
        archive_path => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'archive_path' ],
            is_mutable => 1,
        },
        bam_path => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'bam_path' ],
            is_mutable => 1,
        },
        adaptor_path => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'adaptor_path' ],
            is_mutable => 1,
        },
        rev_clusters => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'rev_clusters' ],
            is_mutable => 1,
        },
        fwd_clusters => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'fwd_clusters' ],
            is_mutable => 1,
        },
        clusters => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'clusters' ],
            is_mutable => 1,
        },
        analysis_software_version => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'analysis_software_version' ],
            is_mutable => 1,
        },
        index_sequence => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'index_sequence' ],
            is_mutable => 1,
        },
        gc_bias_path => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'gc_bias_path' ],
            is_mutable => 1,
        },
        fastqc_path => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'fastqc_path' ],
            is_mutable => 1,
        },
        
        #TODO These three columns will point to "read_length" or whatever name is decided
        #(see also https://gscweb.gsc.wustl.edu/wiki/Software_Development:Illumina_Indexed_Runs_Warehouse_Schema)
        _sls_read_length => { calculate => q| return $self->read_length + 1| },
        _sls_fwd_read_length => { calculate => q| return $self->fwd_read_length + 1| },
        _sls_rev_read_length => { calculate => q| return $self->rev_read_length + 1| },
        cycles => { calculate => q| return $self->read_length + 1| }, 

        short_name => {
            is => 'Text',
            calculate_from => ['run_name'],
            calculate => q|($run_name =~ /_([^_]+)$/)[0]|,
            doc => 'The essential portion of the run name which identifies the run.  The rest is redundant information', 
        },
        is_paired_end => {
            calculate_from => ['run_type'],
            calculate => q| 
                if (defined($run_type) and $run_type =~ m/^Paired$/) {
                    return 1;
                }
                return 0;
            |,
        },
        # TODO Replace with new Genome::Project
        project => {
            is => "Genome::Site::WUGC::Project",
            calculate => q|Genome::Site::WUGC::Project->get(name => $self->project_name)|
        },
        # TODO Refactor this away
        _run_lane_solexa => {
            is => 'GSC::RunLaneSolexa',
            calculate_from => ['id'],
            calculate => q| GSC::RunLaneSolexa->get($id); |,
            doc => 'Solexa Lane Summary from LIMS.',
        },
        # TODO Refactor this away
        index_illumina => {
            doc => 'Index Illumina from LIMS.',
            is => 'GSC::IndexIllumina',
            calculate => q| GSC::IndexIllumina->get(analysis_id=>$id); |,
            calculate_from => [ 'id' ]
        },
    ],
};

sub __display_name__ {
    my $self = $_[0];
    return $self->flow_cell_id . '/' . $self->subset_name;
}

sub _calculate_paired_end_kb_usage {
    my $self = shift;
    my $HEADER_LENGTH = shift;
    $HEADER_LENGTH = $HEADER_LENGTH + 5; # Adding 5 accounts for newlines in the FQ file.
    # If data is paired_end fwd_read_length, rev_read_length, fwd_clusters and rev_clusters
    # should all be defined.
    if (!defined($self->fwd_read_length) or $self->fwd_read_length <= 0) {
        $self->error_message("Instrument data fwd_read_length is either undefined or less than 0.");
        die;
    } elsif (!defined($self->rev_read_length) or $self->rev_read_length <= 0) {
        $self->error_message("Instrument data rev_read_length is either undefined or less than 0.");
        die;
    } elsif (!defined($self->fwd_clusters) or $self->fwd_clusters <= 0) {
        $self->error_message("Instrument data fwd_clusters is either undefined or less than 0.");
        die;
    } elsif (!defined($self->rev_clusters) or $self->rev_clusters <= 0) {
        $self->error_message("Instrument data rev_clusters is either undefined or less than 0.");
        die;
    }
    
    my $fwd = (($self->fwd_read_length + $HEADER_LENGTH) * $self->fwd_clusters)*2;
    my $rev = (($self->rev_read_length + $HEADER_LENGTH) * $self->rev_clusters)*2;
    my $total = ($fwd + $rev) / 1024.0;
    return $total;
}

sub _calculate_non_paired_end_kb_usage {
    my $self = shift;
    my $HEADER_LENGTH = shift;
    $HEADER_LENGTH = $HEADER_LENGTH + 5; # adding 5 accounts for newlines in the FQ file.
    # We will take the max of fwd_read_length or rev_read_length and the max of fwd_clusters and rev_clusters
    # to make sure that even strange data won't cause overly low space allocation
    # Get the max read length.
    my $max_read_length;
    if ( defined($self->read_length) and $self->read_length > 0 ) {
        $max_read_length = $self->read_length;
    } elsif ( defined($self->fwd_read_length) and defined($self->rev_read_length) ) {
        if ( $self->fwd_read_length > $self->rev_read_length ) {
            $max_read_length = $self->fwd_read_length;
        } else {
            $max_read_length = $self->rev_read_length;
        }
    } elsif ( defined($self->fwd_read_length) and $self->fwd_read_length > 0) {
        $max_read_length = $self->fwd_read_length;
    } elsif ( defined($self->rev_read_length) and $self->rev_read_length > 0) {
        $max_read_length = $self->rev_read_length;
    } else {
        $self->error_message("No valid read length value found in instrument data");
        die;
    }
    # Get the max cluster length.
    my $max_clusters;
    if ( defined($self->clusters) and $self->clusters > 0 ) {
        $max_clusters = $self->clusters;
    } elsif ( defined($self->fwd_clusters) and defined($self->rev_clusters) ) {
        if ( $self->fwd_clusters > $self->rev_clusters ) {
            $max_clusters = $self->fwd_clusters;
        } else {
            $max_clusters = $self->rev_clusters;
        }
    } elsif ( defined($self->fwd_clusters) and $self->fwd_clusters > 0) {
        $max_clusters = $self->fwd_clusters;
    } elsif ( defined($self->rev_clusters) and $self->rev_clusters > 0) {
        $max_clusters = $self->rev_clusters;
    } else {
        $self->error_message("No valid number of clusters value found in instrument data");
        die;
    }
    
    my $total_b = (($max_read_length + $HEADER_LENGTH) * $max_clusters)*2;
    my $total = $total_b / 1024.0;
    return $total;
}

sub calculate_alignment_estimated_kb_usage {
    my $self = shift;
    # Different aligners will require different levels of overhead, so this should return
    # approximately the total size of the instrument data files.
    # In a FQ file, every read means 4 lines, 2 of length $self->read_length,
    # and 2 of read identifier data. Therefore we can expect the total file size to be 
    # about (($self->read_length + header_size) * $self->fwd_clusters)*2 / 1024
    
    # This is length of the id tag in the FQ file, it looks something like: @HWUSI-EAS712_6171L:2:1:1817:12676#TGACCC/1
    my $HEADER_LENGTH = 45;
    
    if ($self->is_paired_end) {
        return int $self->_calculate_paired_end_kb_usage($HEADER_LENGTH);
    } else {
        return int $self->_calculate_non_paired_end_kb_usage($HEADER_LENGTH);
    }
}

sub resolve_full_path {
    my $self = shift;

    my @fs_path = GSC::SeqFPath->get(
        seq_id => $self->genome_model_run_id,
        data_type => [qw/ duplicate fastq path unique fastq path /],
    )
        or return; # no longer required, we make this ourselves at alignment time as needed

    my %dirs = map { File::Basename::dirname($_->path) => 1 } @fs_path;

    if ( keys %dirs > 1) {
        $self->error_message(
            sprintf(
                'Multiple directories for run %s %s (%s) not supported!',
                $self->run_name,
                $self->lane,
                $self->genome_model_run_id,
            )
        );
        return;
    }
    elsif ( keys %dirs == 0 ) {
        $self->error_message(
            sprintf(
                'No directories for run %s %s (%s)',
                $self->run_name,
                $self->lane,
                $self->id,
            )
        );
        return;
    }

    my ($full_path) = keys %dirs;
    $full_path .= '/' unless $full_path =~ m|\/$|;

    return $full_path;
}

#< Dump to File System >#
sub dump_to_file_system {
    #$self->warning_message("Method 'dump_data_to_file_system' not implemented");
    return 1;
}

sub dump_illumina_fastq_files {
    my $self = shift;

    unless ($self->resolve_quality_converter eq 'sol2phred') {
        $self->error_message("This instrument data is not natively Illumina formatted, cannot dump");
        die $self->error_message;
    }

    return $self->_unprocessed_fastq_filenames(@_);
}

sub dump_solexa_fastq_files {
    my $self = shift;

    unless ($self->resolve_quality_converter eq 'sol2sanger') {
        $self->error_message("This instrument data is not natively Solexa formatted, cannot dump");
        die $self->error_message;
    }

    return $self->_unprocessed_fastq_filenames(@_);
}

sub dump_sanger_fastq_files {
    my $self = shift;

    if (defined $self->bam_path && -s $self->bam_path) {
       $self->status_message("Now using a bam instead"); 
        $DB::single = 1;
       return $self->dump_fastqs_from_bam(@_);
    }

    my @illumina_fastq_pathnames = $self->_unprocessed_fastq_filenames(@_);

    my %params = @_;

    my $requested_directory = delete $params{directory} || Genome::Sys->base_temp_directory;

    my @converted_pathnames;
    my $counter = 0;
    for my $illumina_fastq_pathname (@illumina_fastq_pathnames) {
        my $converted_fastq_pathname;
        if ($self->resolve_quality_converter eq 'sol2sanger') {
            $converted_fastq_pathname = $requested_directory . '/' . $self->id . '-sanger-fastq-'. $counter . ".fastq";
            $self->status_message("Applying sol2sanger quality conversion.  Converting to $converted_fastq_pathname");
            unless (Genome::Model::Tools::Maq::Sol2sanger->execute( use_version       => '0.7.1',
                                                                    solexa_fastq_file => $illumina_fastq_pathname,
                                                                    sanger_fastq_file => $converted_fastq_pathname)) {
                $self->error_message('Failed to execute sol2sanger quality conversion $illumina_fastq_pathname $converted_fastq_pathname.');
                die($self->error_message);
            }
        } elsif ($self->resolve_quality_converter eq 'sol2phred') {
            $converted_fastq_pathname = $requested_directory . '/' . $self->id . '-sanger-fastq-'. $counter . ".fastq";
            $self->status_message("Applying sol2phred quality conversion.  Converting to $converted_fastq_pathname");

            unless (Genome::Model::Tools::Fastq::Sol2phred->execute(fastq_file => $illumina_fastq_pathname,
                                                                    phred_fastq_file => $converted_fastq_pathname)) {
                $self->error_message('Failed to execute sol2phred quality conversion.');
                die($self->error_message);
            }
        } elsif ($self->resolve_quality_converter eq 'none') {
            $self->status_message("No quality conversion required.");
            $converted_fastq_pathname = $illumina_fastq_pathname;
        } else {
            $self->error_message("Undefined quality converter requested, I can't proceed");
            die $self->error_message;
        }
        unless (-e $converted_fastq_pathname && -f $converted_fastq_pathname && -s $converted_fastq_pathname) {
            $self->error_message('Failed to validate the conversion of solexa fastq file '. $illumina_fastq_pathname .' to sanger quality scores');
            die($self->error_message);
        }
        $counter++;

        if (($converted_fastq_pathname ne $illumina_fastq_pathname ) &&
            ($illumina_fastq_pathname =~ m/\/tmp\//)) {

            $self->status_message("Removing original unconverted file from temp space to save disk space:  $illumina_fastq_pathname");
            unlink $illumina_fastq_pathname;
        }
        push @converted_pathnames, $converted_fastq_pathname;
    }    

    return @converted_pathnames;

}

sub dump_trimmed_fastq_files {
    my $self = shift;
    my %params = @_;

    my $data_directory = $params{directory} || Genome::Sys->create_temp_directory;

    my $segment_params = $params{segment_params};

    my $trimmer_name = $params{trimmer_name};
    my $trimmer_version = $params{trimmer_version};
    my $trimmer_params = $params{trimmer_params};

    unless($trimmer_name) {
        return $self->dump_sanger_fastq_files(%$segment_params, directory => $data_directory);
    }

    my @fastq_pathnames = $self->dump_sanger_fastq_files(%$segment_params);
    my @trimmed_fastq_pathnames;
    my $counter = 0;
    for my $input_fastq_pathname (@fastq_pathnames) {
        if($trimmer_name eq 'trimq2_shortfilter') {
            $self->error_message('Trimmer ' . $trimmer_name . ' is not currently supported by this module.');
            die $self->error_message;
        }

        my $trimmed_input_fastq_pathname = $data_directory . '/trimmed-sanger-fastq-' . $counter;
        my $trimmer;
        if ($trimmer_name eq 'fastx_clipper') {
            #THIS DOES NOT EXIST YET
            $trimmer = Genome::Model::Tools::Fastq::Clipper->create(
                params => $trimmer_params,
                version => $trimmer_version,
                input => $input_fastq_pathname,
                output => $trimmed_input_fastq_pathname,
            );
        } elsif ($trimmer_name eq 'far') {
            $trimmer = Genome::Model::Tools::Far::Trimmer->create(
                params => $trimmer_params,
                use_version => $trimmer_version,
                source => $input_fastq_pathname,
                target => $trimmed_input_fastq_pathname,
                far_output => $data_directory .'/far_output_report.txt',
            )
        }
        elsif ($trimmer_name eq 'trim5') {
            $trimmer = Genome::Model::Tools::Fastq::Trim5->create(
                length => $trimmer_params,
                input => $input_fastq_pathname,
                output => $trimmed_input_fastq_pathname,
            );
        }
        elsif ($trimmer_name eq 'bwa_style') {
            my ($trim_qual) = $self->trimmer_params =~ /--trim-qual-level\s*=?\s*(\S+)/;
            $trimmer = Genome::Model::Tools::Fastq::TrimBwaStyle->create(
                trim_qual_level => $trim_qual,
                fastq_file      => $input_fastq_pathname,
                out_file        => $trimmed_input_fastq_pathname,
                qual_type       => 'sanger',  #hardcoded for now
                report_file     => $data_directory.'/trim_bwa_style.report.'.$counter,
            );
        }
        elsif ($trimmer_name =~ /trimq2_(\S+)/) {
            #This is for trimq2 no_filter style
            #move trimq2.report to alignment directory

            my %trimq2_params = (
                fastq_file  => $input_fastq_pathname,
                out_file    => $trimmed_input_fastq_pathname,
                report_file => $data_directory.'/trimq2.report.'.$counter,
                trim_style  => $1,
            );
            my ($qual_level, $string) = $self->_get_trimq2_params($trimmer_params);

            my ($primer_sequence) = $trimmer_params =~ /--primer-sequence\s*=?\s*(\S+)/;
            $trimq2_params{trim_qual_level} = $qual_level if $qual_level;
            $trimq2_params{trim_string}     = $string if $string;
            $trimq2_params{primer_sequence} = $primer_sequence if $primer_sequence;
            $trimq2_params{primer_report_file} = $data_directory.'/trim_primer.report.'.$counter if $primer_sequence;

            $trimmer = Genome::Model::Tools::Fastq::Trimq2::Simple->create(%trimq2_params);
        }
        elsif ($trimmer_name eq 'random_subset') {
            my $seed_phrase = $self->run_name .'_'. $self->id;
            $trimmer = Genome::Model::Tools::Fastq::RandomSubset->create(
                input_read_1_fastq_files => [$input_fastq_pathname],
                output_read_1_fastq_file => $trimmed_input_fastq_pathname,
                limit_type => 'reads',
                limit_value => $trimmer_params,
                seed_phrase => $seed_phrase,
            );
        }
        elsif ($trimmer_name eq 'normalize') {
            my ($read_length,$reads) = split(':',$trimmer_params);
            my $trim = Genome::Model::Tools::Fastq::Trim->execute(
                read_length => $read_length,
                orientation => 3,
                input => $input_fastq_pathname,
                output => $trimmed_input_fastq_pathname,
            );
            unless ($trim) {
                die('Failed to trim reads using test_trim_and_random_subset');
            }
            my $random_input_fastq_pathname = $data_directory . '/random-sanger-fastq-' . $counter;
            $trimmer = Genome::Model::Tools::Fastq::RandomSubset->create(
                input_read_1_fastq_files => [$trimmed_input_fastq_pathname],
                output_read_1_fastq_file => $random_input_fastq_pathname,
                limit_type  => 'reads',
                limit_value => $reads,
                seed_phrase => $self->run_name .'_'. $self->id,
            );
            $trimmed_input_fastq_pathname = $random_input_fastq_pathname;
        }
        else {
            # TODO: modularize the above and refactor until they work in this logic:
            # Then ensure that the trimmer gets to work on paired files, and is
            # a more generic "preprocess_reads = 'foo | bar | baz' & "[1,2],[],[3,4,5]"
            my @params = eval("no strict; no warnings; $trimmer_params");
            if ($@) {
                die "error in params: $@\n$trimmer_params\n";
            }

            my $class_name = 'Genome::Model::Tools::FastQual::Trimmer';
            my @words = split(' ',$trimmer_name);
            for my $word (@words) {
                my @parts = map { ucfirst($_) } split('-',$word);
                $class_name .= "::" . join('',@parts);
            }
            eval {
                $trimmer = $class_name->create(
                    input => [$input_fastq_pathname],
                    output => [$trimmed_input_fastq_pathname],
                    @params,
                );
            };
            unless ($trimmer) {
                $self->error_message(
                    sprintf(
                        "Unknown read trimmer_name %s.  Class $class_name params @params. $@",
                        $trimmer_name,
                        $class_name
                    )
                );
                die($self->error_message);
            }
        }
        unless ($trimmer) {
            $self->error_message('Failed to create fastq trim command');
            die($self->error_message);
        }
        unless ($trimmer->execute) {
            $self->error_message('Failed to execute fastq trim command '. $trimmer->command_name);
            die($self->error_message);
        }

        if ($trimmer_name eq 'normalize') {
            my @empty = ();
            $trimmer->_index(\@empty);
        }

        if ($input_fastq_pathname =~ m/^\/tmp/) {
            $self->status_message("Removing original file before trimming to save space: $input_fastq_pathname");
            unlink($input_fastq_pathname);
        }

        push @trimmed_fastq_pathnames, $trimmed_input_fastq_pathname;
        $counter++;
    }

    return @trimmed_fastq_pathnames;
}

sub _get_trimq2_params {
    my $self = shift;
    my $trimmer_params = shift;

    #for trimq2_shortfilter, input something like "32:#" (length:string) in processing profile as trimmer_params, for trimq2_smart1, input "20:#" (quality_level:string)
    if ($trimmer_params !~ /:/){
        $trimmer_params = '::';
    }
    my ($first_param, $string) = split /\:/, $trimmer_params;

    return ($first_param, $string);
}

sub _unprocessed_fastq_filenames {
    my $self = shift;
    my @fastqs;
    if ($self->is_external) {
        @fastqs = $self->resolve_external_fastq_filenames(@_);
    } else {
        @fastqs = @{$self->resolve_fastq_filenames(@_)};
    }
    return @fastqs;
}

sub desc {
    my $self = shift;
    return $self->full_name .'('. $self->id .')';
}

sub read1_fastq_name {
    my $self = shift;
    my $lane = $self->lane;

    return "s_${lane}_1_sequence.txt";
}

sub read2_fastq_name {
    my $self = shift;
    my $lane = $self->lane;

    return "s_${lane}_2_sequence.txt";
}

sub fragment_fastq_name {
    my $self = shift;
    my $lane = $self->lane;

    return "s_${lane}_sequence.txt";
}

sub resolve_fastq_filenames {
    my $self = shift;
    my $lane = $self->lane;
    my $desc = $self->desc;

    my %params = @_;
    my $paired_end_as_fragment = delete $params{'paired_end_as_fragment'};
    my $requested_directory = delete $params{'directory'} || Genome::Sys->base_temp_directory;

    my @illumina_output_paths;
    my @errors;
    
    # First check the archive directory and second get the gerald directory
    for my $dir_type qw(archive_path gerald_directory) {
        $self->status_message("Now trying to get fastq from $dir_type for $desc");
        
        my $directory = $self->$dir_type;
        $directory = $self->validate_fastq_directory($directory, $dir_type);
        next unless $directory;

        if ($dir_type eq 'archive_path') {
            $directory = $self->dump_illumina_fastq_archive($requested_directory); #need eval{} here ?
            $directory = $self->validate_fastq_directory($directory, 'dump_fastq_dir');
            next unless $directory;
        }

        eval {
            #handle fragment or paired-end data
            if ($self->is_paired_end) {
                if (!$paired_end_as_fragment || $paired_end_as_fragment == 1) {
                    if (-e "$directory/" . $self->read1_fastq_name) {
                        push @illumina_output_paths, "$directory/" . $self->read1_fastq_name;
                    } 
                    elsif (-e "$directory/Temp/" . $self->read1_fastq_name) {
                        push @illumina_output_paths, "$directory/Temp/" . $self->read1_fastq_name;
                    } 
                    else {
                        die "No illumina forward data in directory for lane $lane! $directory";
                    }
                }
                if (!$paired_end_as_fragment || $paired_end_as_fragment == 2) {
                    if (-e "$directory/" . $self->read2_fastq_name) {
                        push @illumina_output_paths, "$directory/" . $self->read2_fastq_name;
                    } 
                    elsif (-e "$directory/Temp/" . $self->read2_fastq_name) {
                        push @illumina_output_paths, "$directory/Temp/" . $self->read2_fastq_name;
                    } 
                    else {
                        die "No illumina reverse data in directory for lane $lane! $directory";
                    }
                }
            } 
            else {
                if (-e "$directory/" . $self->fragment_fastq_name) {
                    push @illumina_output_paths, "$directory/" . $self->fragment_fastq_name;
                } 
                elsif (-e "$directory/Temp/" . $self->fragment_fastq_name) {
                    push @illumina_output_paths, "$directory/Temp/" . $self->fragment_fastq_name;
                } 
                else {
                    die "No fragment illumina data in directory for lane $lane! $directory";
                }
            }
        };
            
        push @errors, $@ if $@;
        last if @illumina_output_paths;
    }
    unless (@illumina_output_paths) {
        $self->error_message("No fastq files were found for $desc");
        $self->error_message(join("\n",@errors)) if @errors;
        die $self->error_message;
    }
    return \@illumina_output_paths;
}


sub dump_illumina_fastq_archive {
    my ($self, $dir) = @_;

    my $archive = $self->archive_path;
    $dir = Genome::Sys->base_temp_directory unless $dir;

    #Prevent unarchiving multiple times during execution
    #Hopefully nobody passes in a $dir expecting to overwrite another set of FASTQs coincidentally from the same lane number
    my $already_dumped = 0;
    
    if($self->is_paired_end) {
        if (-s $dir . '/' . $self->read1_fastq_name and -s $dir . '/' . $self->read2_fastq_name) {
            $already_dumped = 1;
        }
    } 
    else {
        if (-s $dir . '/' . $self->fragment_fastq_name) {
            $already_dumped = 1;
        }
    }

    unless($already_dumped) {
        my $cmd = "tar -xzf $archive --directory=$dir";
        unless (Genome::Sys->shellcmd(
            cmd => $cmd,
            input_files => [$archive],
        )) {
            $self->error_message('Failed to run tar command '. $cmd);
            return;
            #die($self->error_message); Should try to get fastq from gerald_directory instead of dying
        }
    }
    return $dir;
}

sub validate_fastq_directory {
    my ($self, $dir, $dir_type) = @_;
    
    my $msg_base = "$dir_type : $dir";
    
    unless ($dir) {
        $self->error_message("$msg_base is null");
        return;
    }

    unless (-e $dir) {
        $self->error_message("$msg_base not existing in file system");
        return;
    }

    unless ($dir_type eq 'archive_path') {
        my @files = glob("$dir/*"); #In scalar context, a glob functions as an iterator--we instead want to check the number of files
        unless (scalar @files) {
            $self->error_message("$msg_base is empty");
            return;
        }
    }

    return $dir;
}

    
sub resolve_external_fastq_filenames {
    my $self = shift;

    my @fastq_pathnames;
    my $fastq_pathname = $self->create_temp_file_path('fastq');
    unless ($fastq_pathname) {
        die "Failed to create temp file for fastq!";
    }
    return ($fastq_pathname);
}

sub _calculate_total_read_count {
    my $self = shift;

    if($self->is_external) {
        my $data_path_object = Genome::MiscAttribute->get(entity_id => $self->id, property_name=>'full_path');
        my $data_path = $data_path_object->value;
        my $lines = `wc -l $data_path`;
        return $lines/4;
    }
    if ($self->clusters <= 0) {
        die('Impossible value '. $self->clusters .' for clusters field for solexa lane '. $self->id);
    }

    return $self->clusters;
}

sub resolve_quality_converter {

    # old stuff needed sol2sanger, new stuff all uses sol2phred, but
    # we dont care what the version is anymore

    my $self = shift;

    my %analysis_software_versions = (
                                     'GAPipeline-0.3.0'       => 'sol2sanger',
                                     'GAPipeline-0.3.0b1'     => 'sol2sanger',
                                     'GAPipeline-0.3.0b2'     => 'sol2sanger',
                                     'GAPipeline-0.3.0b3'     => 'sol2sanger',
                                     'GAPipeline-1.0'         => 'sol2sanger',
                                     'GAPipeline-1.0-64'      => 'sol2sanger',
                                     'GAPipeline-1.0rc4'      => 'sol2sanger',
                                     'GAPipeline-1.1rc1p4'    => 'sol2sanger',
                                     'SolexaPipeline-0.2.2.5' => 'sol2sanger',
                                     'SolexaPipeline-0.2.2.6' => 'sol2sanger',
                                 );

    my $analysis_software_version = $self->analysis_software_version;
    unless ($analysis_software_version) {
        die('No analysis_software_version found for instrument data '. $self->id);
    }

    return $analysis_software_versions{$analysis_software_version} || 'sol2phred';
}

sub resolve_adaptor_file {
    my $self = shift;

    #these are constants and should probably be defined in class properties...TODO
    my $dna_primer_file = '/gscmnt/sata114/info/medseq/adaptor_sequences/solexa_adaptor_pcr_primer';
    my $rna_primer_file = '/gscmnt/sata114/info/medseq/adaptor_sequences/solexa_adaptor_pcr_primer_SMART';

    my $adaptor_file;
    if ( $self->sample_type eq 'rna' ) {
        $adaptor_file = $rna_primer_file;
    }
    else {
        $adaptor_file = $dna_primer_file;
    }
    unless (-f $adaptor_file) {
        $self->error_message('Specified adaptor file'. $adaptor_file .' does not exist.');
        die($self->error_message);
    }
    return $adaptor_file;
}

sub create_mock {
    my $class = shift;
    my $self = $class->SUPER::create_mock(@_);
    return unless $self;

    for my $method (qw/
        dump_sanger_fastq_files
        resolve_fastq_filenames
        _calculate_total_read_count
        resolve_adaptor_file
        run_identifier
    /) {
        my $ref = $class->can($method);
        die "Unknown method $method on " . $class . ".  Cannot make a pass-through for mock object!" unless $ref;
        $self->mock($method,$ref);
    }

    return $self;
}

sub run_start_date_formatted {
    my $self = shift;

    my ($y, $m, $d) = $self->run_name =~ m/^(\d{2})(\d{2})(\d{2})_.*$/;

    my $dt_format = UR::Time->config('datetime');
    #UR::Time->config(datetime => '%a %b %d %T %Z %Y');
    UR::Time->config(datetime => '%Y-%m-%d');
    my $dt = UR::Time->numbers_to_datetime(0, 0, 0, $d, $m, "20$y");
    UR::Time->config(datetime => $dt_format);

    return $dt;
}

sub total_bases_read {
    my $self = shift;
    my $filter = shift; # optional?
    if(!defined($filter))
    {
        $filter = 'both';
    }
    my $total_bases; # unused?


    my $count;
    if ($self->is_paired_end) {
        # this changed in case we only want the fwd or rev counts...
        $count += ($self->fwd_read_length * $self->fwd_clusters)  unless $filter eq 'reverse-only';
        $count += ($self->rev_read_length * $self->rev_clusters) unless $filter eq 'forward-only';
    } else {
        $count += ($self->read_length * $self->clusters);
    }

    return $count;
}

sub summary_xml_content {
    my $self = shift;
    my $rls = $self->_run_lane_solexa;
    unless ($rls) { return; }
    return $rls->summary_xml_content;
}

sub run_identifier {
    my $self = shift;
    return $self->flow_cell_id;
}

1;

#$HeaderURL$
#$Id: Solexa.pm 61055 2010-07-16 19:30:48Z boberkfe $
