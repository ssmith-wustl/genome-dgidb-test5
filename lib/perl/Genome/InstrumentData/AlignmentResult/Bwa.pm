package Genome::InstrumentData::AlignmentResult::Bwa;

use strict;
use warnings;
use File::Basename;
use Data::Dumper;
use Carp qw/confess/;
use Genome;

class Genome::InstrumentData::AlignmentResult::Bwa {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'bwa', is_param=>1 },
    ],
    has_optional => [
         _bwa_sam_cmd => { is=>'Text' }
    ]
};

sub required_arch_os { 'x86_64' }

sub required_rusage {
    my $class = shift;
    my %p = @_;
    my $instrument_data = delete $p{instrument_data};

    my $tmp_mb = $class->tmp_megabytes_estimated($instrument_data);
    my $mem_mb = 10240;
    my $cpus = 4;
    
    my $mem_kb = $mem_mb*1024;
    my $tmp_gb = $tmp_mb/1024;

    my $user = getpwuid($<);
    my $queue = ($user eq 'apipe-builder' ? 'alignment-pd' : 'alignment');

    my $host_groups;
    $host_groups = qx(bqueues -l $queue | grep ^HOSTS:);
    $host_groups =~ s/\/\s+/\ /;
    $host_groups =~ s/^HOSTS:\s+//;

    my $select  = "select[ncpus >= $cpus && mem >= $mem_mb && gtmp >= $tmp_gb] span[hosts=1]";
    my $rusage  = "rusage[mem=$mem_mb, gtmp=$tmp_gb]";
    my $options = "-M $mem_kb -n $cpus -q $queue";

    my $required_usage = "-R '$select $rusage' $options";

    my @selected_blades = `bhosts -R '$select' $host_groups | grep ^blade`;

    if (@selected_blades) {
        return $required_usage;
    } else {
        die $class->error_message("Failed to find hosts that meet resource requirements ($required_usage).");
    }
}

sub tmp_megabytes_estimated {
    my $class = shift || die;
    my $instrument_data = shift;

    my $default_megabytes = 90000;


    if (not defined $instrument_data) {
        return $default_megabytes;
    }
    elsif ($instrument_data->bam_path) {
        my $bam_path = $instrument_data->bam_path;

        my $scale_factor = 3.25; # assumption: up to 3x during sort/fixmate/sort and also during fastq extraction (2x) + bam = 3

        my $bam_bytes = -s $bam_path;
        unless ($bam_bytes) {
            die $class->error_message("Instrument Data has BAM ($bam_path) but has no size!");
        }

        if ($instrument_data->can('get_segments')) {
            my $bam_segments = scalar $instrument_data->get_segments;
            if ($bam_segments > 1) {
                $scale_factor = $scale_factor / $bam_segments;
            }
        }

        return int(($bam_bytes * $scale_factor) / 1024**2);
    }
    elsif ($instrument_data->can("calculate_alignment_estimated_kb_usage")) {
        my $kb_usage = $instrument_data->calculate_alignment_estimated_kb_usage;
        return int(($kb_usage * 3) / 1024) + 100; # assumption: 2x for the quality conversion, one gets rm'di after; aligner generates 0.5 (1.5 total now); rm orig; sort and merge maybe 2-2.5
    }
    else {
        return $default_megabytes;
    }

    return;
}

sub _all_reference_indices {
    my $self = shift;

    my @indices;
    if ($self->multiple_reference_mode) {
        my $b = $self->reference_build;
        do {
            $self->status_message("Getting reference sequence index for build ".$b->__display_name__);
            push(@indices, $self->get_reference_sequence_index($b));
            $b = $b->append_to;
        } while ($b);
    } else {
        push(@indices, $self->get_reference_sequence_index);
    }
    return @indices;
}

sub _intermediate_result {
    my ($self, $params, $index, @input_files) = @_;

    my @results;
    for my $idx (0..$#input_files) {
        my $path = $input_files[$idx];
        my ($input_pass) = $path =~ m/\.bam:(\d)$/;
        $DB::single=1;
        print "INPUT FILE: $path, INPUT PASS: $input_pass\n" . Dumper(\@_);
        if (defined($input_pass)) {
            $path =~ s/\.bam:\d$/\.bam/;
        } else {
            $input_pass = $idx+1;
        }
 
        my %intermediate_params = (
            instrument_data => $self->instrument_data,
            aligner_name => $self->aligner_name,
            aligner_version => $self->aligner_version,
            aligner_params => $params,
            aligner_index => $index,
            parent_result => $self,
            input_file => $path,
            input_pass => $input_pass,
            instrument_data_segment_type => $self->instrument_data_segment_type,
            instrument_data_segment_id => $self->instrument_data_segment_id,
        ); 

        my $intermediate_result = Genome::InstrumentData::IntermediateAlignmentResult::Bwa->get_or_create(%intermediate_params);
        unless ($intermediate_result) {
            confess "Failed to generate IntermediateAlignmentResult for $path, params were: " . Dumper(\%intermediate_params);
        }
        push(@results, $intermediate_result);
    }

    return @results;
}

sub _samxe_cmdline {
    my ($self, $aligner_params, $input_groups, @input_pathnames) = @_;

    my $cmdline;
    if (@input_pathnames == 1) {
        my $params = $aligner_params->{'bwa_samse_params'} || '';
        $self->_bwa_sam_cmd("bwa samse " . $params);

        unless (scalar @$input_groups == 1) {
            die "Multiple reference mode not supported for bwa samse!";
        }

        my $aligner_index = $input_groups->[0]->{aligner_index};
        my $intermediate_results = $input_groups->[0]->{intermediate_results};
        $cmdline = sprintf("samse $params %s %s %s",
            $aligner_index->full_consensus_path('fa'),
            $input_groups->[0]->{intermediate_results}->[0]->sai_file,
            $input_pathnames[0]);

    } elsif (@input_pathnames == 2) {
        my $params = $self->_derive_bwa_sampe_parameters;
        $self->_bwa_sam_cmd("bwa sampe " . $params);

        my @cmdline_inputs;
        for my $group (@$input_groups) {
            my $aligner_index = $group->{aligner_index};
            my $intermediate_results = $group->{intermediate_results};
            push(@cmdline_inputs,
                $aligner_index->full_consensus_path('fa'),
                map { $_->sai_file } @$intermediate_results,
                );
        }

        # fastq/bam input files come after the first set of "ref.fa seq1.sai seq2.sai"
        # insert them where they need to go
        splice(@cmdline_inputs, 3, 0, @input_pathnames);
        $cmdline = "sampe $params " . join(' ', @cmdline_inputs);
    } else {
        $self->error_message("Input pathnames should have 2 elements... contents: " . Dumper(\@input_pathnames) );
    }

    return $cmdline;
}

sub _run_aligner {
    my $self = shift;
    my @input_pathnames = @_;

    my $tmp_dir = $self->temp_scratch_directory;

    # get refseq info
    my $reference_build = $self->reference_build;
    my $reference_fasta_path = $self->get_reference_sequence_index->full_consensus_path('fa');

    # decompose aligner params for each stage of bwa alignment
    my %aligner_params = $self->decomposed_aligner_params;
   
    #### STEP 1: Use "bwa aln" to align each fastq independently to the reference sequence 

    my $bwa_aln_params = (defined $aligner_params{'bwa_aln_params'} ? $aligner_params{'bwa_aln_params'} : "");
    my @indices = $self->_all_reference_indices;
    my @input_groups;
    my @aln_log_files;
    for my $index (@indices) {
        my @results = $self->_intermediate_result($bwa_aln_params, $index, @input_pathnames);
        push(@input_groups, {
                aligner_index => $index,
                intermediate_results => [ @results ],
            }
        );
        push(@aln_log_files, map { $_->log_file } @results);
    }

    #### STEP 2: Use "bwa samse" or "bwa sampe" to perform single-ended or paired alignments, respectively.
    #### Runs once for ALL input files

    map { s/\.bam:\d/.bam/ } @input_pathnames; # strip :[12] suffix from bam files if present

    my $samxe_logfile = $tmp_dir . "/bwa.samxe.log"; 
    my $samxe_cmdline = $self->_samxe_cmdline(\%aligner_params, \@input_groups, @input_pathnames);
    my $sam_file = $self->temp_scratch_directory . "/all_sequences.sam";

    my $sam_command_line = sprintf("%s $samxe_cmdline 2>> $samxe_logfile",
        Genome::Model::Tools::Bwa->path_for_bwa_version($self->aligner_version));

    unless ($self->_filter_samxe_output($sam_command_line, $sam_file)) {
        die "Failed to process sam command line, error_message is ".$self->error_message;
    }

    unless (-s $sam_file) {
        die "The sam output file $sam_file is zero length; something went wrong.";
    }

    for my $file (@input_pathnames) {
        if ($file =~ m/^\/tmp\//) {
            $self->status_message("removing $file to save space!");
            unlink($file);
        }
    }

    #### STEP 3: Merge log files.
 
    my $log_input_fileset = join " ",  (@aln_log_files, $samxe_logfile);
    my $log_output_file   = $self->temp_staging_directory . "/aligner.log";
    my $concat_log_cmd = sprintf('cat %s >> %s', $log_input_fileset, $log_output_file);

    Genome::Sys->shellcmd(
        cmd          => $concat_log_cmd,
        input_files  => [ @aln_log_files, $samxe_logfile ],
        output_files => [ $log_output_file ],
        skip_if_output_is_present => 0,
        );

    return 1;
}

sub _filter_samxe_output {
    my ($self, $sam_cmd, $sam_file_name) = @_;

#    my $cmd = "$sam_cmd | grep -v ^@ >> $sam_file_name";
#    print $cmd,"\n\n";
#    $DB::single = 1;
#    Genome::Sys->shellcmd(cmd => $cmd);
#    return 1;

    $DB::single = 1;
    my $sam_run_output_fh = IO::File->new( $sam_cmd . "|" );
    binmode $sam_run_output_fh;
    $self->status_message("Running $sam_cmd");
    if ( !$sam_run_output_fh ) {
            $self->error_message("Error running $sam_cmd $!");
            return;
    }

    my $sam_map_output_fh = IO::File->new(">>$sam_file_name");
    binmode $sam_map_output_fh;
    if ( !$sam_map_output_fh ) {
            $self->error_message("Error opening sam file for writing $!");
            return;
    }
    $self->status_message("Opened $sam_file_name.  Now streaming this through the read group addition.");
   
    my $sam_out_fh; 
    # UGLY HACK: the multi-aligner code redefines this to zero so it can extract sam files.
    if ($self->supports_streaming_to_bam) { 
        $sam_out_fh = $self->_bam_output_fh; 
    } else {
        $sam_out_fh = IO::File->new(">>" . $self->temp_scratch_directory . "/all_sequences.sam");
    }
    my $add_rg_cmd = Genome::Model::Tools::Sam::AddReadGroupTag->create(
            input_filehandle     => $sam_run_output_fh,
            output_filehandle    => $sam_out_fh,
            read_group_tag => $self->read_and_platform_group_tag_id,
            pass_sam_headers => 0,
        );

    unless ($add_rg_cmd->execute) {
        $self->error_message("Adding read group to sam file failed!");
        die $self->error_message;
    }
    
    $sam_run_output_fh->close;
    $sam_map_output_fh->close;

    return 1;
}


sub _verify_bwa_aln_did_happen {
    my $self = shift;
    my %p = @_;

    unless (-e $p{sai_file} && -s $p{sai_file}) {
        $self->error_message("Expected SAI file is $p{sai_file} nonexistent or zero length.");
        return;
    }
    
    unless ($self->_inspect_log_file(log_file=>$p{log_file},
                                     log_regex=>'(\d+) sequences have been processed')) {
        
        $self->error_message("Expected to see 'X sequences have been processed' in the log file where 'X' must be a nonzero number.");
        return 0;
    }
    
    return 1;
}

sub _inspect_log_file {
    my $self = shift;
    my %p = @_;

    my $log_file = $p{log_file};
    unless ($log_file and -s $log_file) {
        $self->error_message("log file $log_file is not valid");
        return;
    }

    my $last_line = `tail -1 $log_file`;    
    my $check_nonzero = 0;
    
    my $log_regex = $p{log_regex};
    if ($log_regex =~ m/\(\\d\+\)/) {
        $check_nonzero = 1;
    }

    if ($last_line =~ m/$log_regex/) {
        if ( !$check_nonzero || $1 > 0 ) {
            $self->status_message('The last line of aligner.log matches the expected pattern');
            return 1;
        }
    }
    
    $self->error_message("The last line of $log_file is not valid: $last_line");
    return;
}


sub decomposed_aligner_params {
    my $self = shift;
    my $params = $self->aligner_params || ":::";
    
    my @spar = split /\:/, $params;

    my $bwa_aln_params = $spar[0] || ""; 

    my $cpu_count = $self->_available_cpu_count;    

    $self->status_message("[decomposed_aligner_params] cpu count is $cpu_count");
  
    $self->status_message("[decomposed_aligner_params] bwa aln params are: $bwa_aln_params");

    if (!$bwa_aln_params || $bwa_aln_params !~ m/-t/) {
        $bwa_aln_params .= "-t$cpu_count";
    } elsif ($bwa_aln_params =~ m/-t/) {
        $bwa_aln_params =~ s/-t ?\d/-t$cpu_count/;
    }

    $self->status_message("[decomposed_aligner_params] autocalculated CPU requirement, bwa aln params modified: $bwa_aln_params");

    
    return ('bwa_aln_params' => $bwa_aln_params, 'bwa_samse_params' => $spar[1], 'bwa_sampe_params' => $spar[2]);
}

sub aligner_params_for_sam_header {
    my $self = shift;
    
    my %params = $self->decomposed_aligner_params;
    my $aln_params = $params{bwa_aln_params} || "";
  
    if ($self->instrument_data->is_paired_end) {
        $self->_derive_bwa_sampe_parameters;
    } 
    my $sam_cmd = $self->_bwa_sam_cmd || "";

    return "bwa aln $aln_params; $sam_cmd ";
}

sub _derive_bwa_sampe_parameters {
    my $self = shift;
    my %aligner_params = $self->decomposed_aligner_params;
    my $bwa_sampe_params = (defined $aligner_params{'bwa_sampe_params'} ? $aligner_params{'bwa_sampe_params'} : "");
    
    # Ignore where we have a -a already specified
    if ($bwa_sampe_params =~ m/\-a\s*(\d+)/) {
        $self->status_message("Aligner params specify a -a parameter ($1) as upper bound on insert size.");
    } else {
        # come up with an upper bound on insert size.
        my $instrument_data = $self->instrument_data;
        my $sd_above = $instrument_data->sd_above_insert_size;
        my $median_insert = $instrument_data->median_insert_size;
        my $upper_bound_on_insert_size= ($sd_above * 5) + $median_insert;
        if($upper_bound_on_insert_size > 0) {
            $self->status_message("Calculated a valid insert size as $upper_bound_on_insert_size.  This will be used when BWA's internal algorithm can't determine an insert size");
        } else {
            $self->status_message("Unable to calculate a valid insert size to run BWA with. Using 600 (hax)");
            $upper_bound_on_insert_size= 600;
        }

        $bwa_sampe_params .= " -a $upper_bound_on_insert_size";
    }

    # store the calculated sampe params
    $self->_bwa_sam_cmd("bwa sampe " . $bwa_sampe_params);
    return $bwa_sampe_params;
}

sub fillmd_for_sam {
    return 0;
}

sub requires_read_group_addition {
    return 0;
}

sub supports_streaming_to_bam {
    return 1;
}

sub multiple_reference_mode {
    my $self = shift;
    return $self->reference_build->append_to and Genome::Model::Tools::Bwa->multiple_reference($self->aligner_version);
}

sub accepts_bam_input {
    my $self = shift;
    return Genome::Model::Tools::Bwa->supports_bam_input($self->aligner_version);
}

sub prepare_reference_sequence_index {
    my $class = shift;
    my $refindex = shift;

    my $staging_dir = $refindex->temp_staging_directory;
    my $staged_fasta_file = sprintf("%s/all_sequences.fa", $staging_dir);

    my $actual_fasta_file = $staged_fasta_file;

    if (-l $staged_fasta_file) {
        $class->status_message(sprintf("Following symlink for fasta file %s", $staged_fasta_file));
        $actual_fasta_file = readlink($staged_fasta_file);
        unless($actual_fasta_file) {
            $class->error_message("Can't read target of symlink $staged_fasta_file");
            return;
        } 
    }

    $class->status_message(sprintf("Checking size of fasta file %s", $actual_fasta_file));

    my $fasta_size = -s $actual_fasta_file;
    my $bwa_index_algorithm = ($fasta_size < 11_000_000) ? "is" : "bwtsw";
    my $bwa_path = Genome::Model::Tools::Bwa->path_for_bwa_version($refindex->aligner_version);

    $class->status_message(sprintf("Building a BWA index in %s using %s.  The file size is %s; selecting the %s algorithm to build it.", $staging_dir, $staged_fasta_file, $fasta_size, $bwa_index_algorithm));

    # expected output files from bwa index
    my @output_files = map {sprintf("%s.%s", $staged_fasta_file, $_)} qw(amb ann bwt pac rbwt rpac rsa sa);

    my $bwa_cmd = sprintf('%s index -a %s %s', $bwa_path, $bwa_index_algorithm, $staged_fasta_file);
    my $rv = Genome::Sys->shellcmd(
        cmd => $bwa_cmd,
        input_files => [$staged_fasta_file],
        output_files => [@output_files]
    );

    unless($rv) {
        $class->error_message('bwa indexing failed');
        return;
    }

    return 1;
}
