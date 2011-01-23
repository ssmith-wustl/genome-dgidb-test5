package Genome::InstrumentData::AlignmentResult::Maq;

use strict;
use warnings;

use File::Basename;
use IO::File;
use Genome;

class Genome::InstrumentData::AlignmentResult::Maq {
    is  => ['Genome::InstrumentData::AlignmentResult'],
    has_constant => [
        aligner_name => { value => 'maq', is_param => 1 },
    ],
    has => [
        _maq_cmd                 => { is => 'Text' },
        is_not_run_as_paired_end => {
            type => 'Boolean',
            calculate_from => ['filter_name', 'force_fragment'],
            calculate => q{return $force_fragment
                || ($filter_name && (($filter_name eq 'forward-only')
                || ($filter_name eq 'reverse-only'))); 
            },
        },
    ]
};

sub required_arch_os { 
    'x86_64' 
}

sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[tmp=50000:mem=12000]' -M 1610612736";
}

sub extra_metrics {
    'contaminated_read_count'
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

    my ($line_of_interest) = grep { /total, isPE, mapped, paired/ } @lines;
    unless ($line_of_interest) {
        $self->error_message('Aligner summary statistics line not found');
        return;
    }
    my ($comma_separated_metrics) = ($line_of_interest =~ m/= \((.*)\)/);
    my @values = split(/,\s*/,$comma_separated_metrics);

    return {
        total  => $values[0],
        isPE   => $values[1],
        mapped => $values[2],
        paired => $values[3],
    };
}


sub verify_aligner_successful_completion {
    my $self = shift;
    my $aligner_output_file = shift;
    
    my $instrument_data = $self->instrument_data;
    if ($instrument_data->is_paired_end) {
        my $stats = $self->get_alignment_statistics($aligner_output_file);
        unless ($stats) {
            return $self->_aligner_output_file_complete($aligner_output_file);
        }
        if ($self->is_not_run_as_paired_end) {
            if ($$stats{'isPE'} != 0) {
                $self->error_message('Paired-end instrument data '. $instrument_data->id .' was not aligned as fragment data according to aligner output '. $aligner_output_file);
                return;
            }
        }  
        else {
            if ($$stats{'isPE'} != 1) {
                $self->error_message('Paired-end instrument data '. $instrument_data->id .' was not aligned as paired end data according to aligner output '. $aligner_output_file);
                return;
            }
        }
    }
    return $self->_aligner_output_file_complete($aligner_output_file);
}


sub _aligner_output_file_complete {
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
    while(<$aligner_output_fh>) {
        if (m/match_data2mapping/) {
            $aligner_output_fh->close();
            return 1;
        }
        if (m/\[match_index_sorted\] no reasonable reads are available. Exit!/) {
            $aligner_output_fh->close();
            return 2;
        }
    }
    return;
}


#####ALIGNER OUTPUT#####
#the fully quallified file path for aligner output
sub aligner_output_file_path {
    my $self = shift;
    my $lane = $self->instrument_data->subset_name;
    #return $self->temp_scratch_directory . "/alignments_lane_${lane}.map.aligner_output";
    return $self->temp_staging_directory . '/aligner.log';
}


#####UNALIGNED READS LIST#####
#the fully quallified file path for unaligned reads
sub unaligned_reads_list_path {
    my $self        = shift;
    my $subset_name = $self->instrument_data->subset_name;
    return $self->temp_scratch_directory . "/s_${subset_name}_sequence.unaligned";
}

# return list of generated map files for alignments that have completed and been synced to network disk
sub alignment_file_paths {
    my $self = shift;
    my $dir = $self->output_dir;

    return glob($dir . "/*.map");
}

sub _run_aligner {
    my $self = shift;
    
    my @input_pathnames = @_;
    @input_pathnames    = $self->input_bfq_filenames(@input_pathnames);

    my $tmp_dir         = $self->temp_scratch_directory;
    my $instrument_data = $self->instrument_data;
    my $aligner_params  = $self->aligner_params;

    my $reference_build = $self->reference_build;
    my $ref_seq_file    = $reference_build->full_consensus_path('bfa');

    unless ($ref_seq_file && -e $ref_seq_file) {
        $self->error_message("Reference build full consensus path '$ref_seq_file' does not exist.");
        die $self->error_message;
    }
    $self->status_message("REFSEQ PATH: $ref_seq_file\n");

    my $map_file       = $self->temp_staging_directory .'/all_sequences.map';
    my $align_out_file = $self->aligner_output_file_path;
    my $unaligned_list = $self->unaligned_reads_list_path;

    # RESOLVE A STRING OF ALIGNMENT PARAMETERS
    my $upper_bound_on_insert_size;
    my $median_insert;

    if (@input_pathnames == 2) {  #paired end
        my $sd_above   = $instrument_data->sd_above_insert_size;
        $median_insert = $instrument_data->median_insert_size;
        $upper_bound_on_insert_size= ($sd_above * 5) + $median_insert;
        
        unless ($upper_bound_on_insert_size > 0) {
            $self->status_message("Unable to calculate a valid insert size to run maq with. Using 600 (hax)");
            $upper_bound_on_insert_size= 600;
        }

        if ($median_insert < 1000){
		    $aligner_params .= ' -a '. $upper_bound_on_insert_size;
		    $self->status_message("Median insert size ($median_insert) less than 1000, setting -a");
        }
	    elsif ($median_insert >= 1000){
		    $aligner_params .= ' -A '. $upper_bound_on_insert_size;
		    $self->status_message("Median insert size ($median_insert) greater than or equal to 1000, setting -A");
        }
	    else {
	        #in the future we need to make an intelligent decision about setting -a vs -A based on the intended insert size
	        #we should only be here in the case where gerald failed to calculate a median insert size
	        #TODO: extract additional details from the read set (that is what the guy at line 477 thought)
            $self->warning_message('Gerald failed to calculate a median insert size');
        }
    }

    # TODO: this doesn't really work, so leave it out
    my $adaptor_file = $instrument_data->resolve_adaptor_file;
    
    if ($adaptor_file and -s $adaptor_file) {
        $aligner_params .= ' -d '. $adaptor_file;
    }
    else {
        $self->error_message("Failed to resolve adaptor file or adaptor file is not existing or is empty!");
        die $self->error_message;
    }

    # prevent randomness!  seed the generator based on the flow cell not the clock
    my $seed = 0; 
    for my $c (split(//,$instrument_data->flow_cell_id || $self->instrument_data_id)) {
        $seed += ord($c)
    }
    $seed = $seed % 65536;
    $self->status_message("Seed for maq's random number generator is $seed.");
    $aligner_params .= " -s $seed ";

    # disconnect the db handle before this long-running event
    Genome::DataSource::GMSchema->disconnect_default_dbh; 


    my $files_to_align = join ' ', @input_pathnames;
    my $cmdline = Genome::Model::Tools::Maq->path_for_maq_version($self->aligner_version)
        . sprintf(' map %s -u %s %s %s %s > ',
            $aligner_params,
            $unaligned_list,
            $map_file,
            $ref_seq_file,
            $files_to_align
        ) . $align_out_file . ' 2>&1';
        
    my @input_files  = ($ref_seq_file, @input_pathnames, $adaptor_file);
    my @output_files = ($map_file, $unaligned_list, $align_out_file);
    
    Genome::Sys->shellcmd(
        cmd          => $cmdline,
        input_files  => \@input_files,
        output_files => \@output_files,
    );

    $self->_maq_cmd($cmdline);
    
    unless ($self->verify_aligner_successful_completion($align_out_file)) {
        $self->error_message('Failed to verify maq successful completion from output file '. $align_out_file);
        die $self->error_message;
    }

    # in some cases maq will "work" but not make an unaligned reads file
    # this happens when all reads are filtered out
    # make an empty file to represent our zero-item list of unaligned reads
    unless (-e $unaligned_list) {
        if (my $fh = IO::File->new(">$unaligned_list")) {
            $self->status_message("Made empty unaligned reads file since that file is was not generated by maq.");
        } 
        else {
            $self->error_message("Failed to make empty unaligned reads file!: $!");
        }
    }

    # TODO: Move this logic into a diff utility that performs the "sanitization"
    # make a sanitized version of the aligner output for comparisons
    my $output = Genome::Sys->open_file_for_reading($align_out_file);
    my $clean  = Genome::Sys->open_file_for_writing($align_out_file . '.sanitized');
    while (my $row = $output->getline) {
        $row =~ s/\% processed in [\d\.]+/\% processed in N/;
        $row =~ s/CPU time: ([\d\.]+)/CPU time: N/;
        $clean->print($row);
    }
    $output->close;
    $clean->close;

    unless ($self->create_aligned_sam_file($map_file)) {
        $self->error_message("Failed to create temp aligned all_sequences.sam from $map_file");
        die $self->error_message;
    }
        
    unless ($self->create_unaligned_sam_file) {
        $self->error_message('Failed to create temp unaligned sam file');
        die $self->error_message;
    }
    
    $self->status_message('Finished Maq aligning!');
    return 1;
}


sub create_aligned_sam_file {
    my ($self, $map_file) = @_;
    $self->status_message("Converting maq aligned reads to sam format for $map_file");
    
    my $samtools   = Genome::Model::Tools::Sam->path_for_samtools_version($self->samtools_version);
    my $tool_path  = dirname $samtools;
    my $tosam_path = $tool_path.'/misc/maq2sam-';

    my ($ver) = $self->aligner_version =~ /^\D*\d\D*(\d)\D*\d/;
    $self->error_message("Give correct maq version") and return unless $ver;
    $tosam_path = $ver < 7 ? $tosam_path.'short' : $tosam_path.'long';

    my $sam_file = $self->temp_scratch_directory . '/all_sequences.sam';
    
    my $cmd = sprintf('%s %s >> %s', $tosam_path, $map_file, $sam_file); #use append to allow multiple maq runs
    my $rv  = Genome::Sys->shellcmd(
        cmd                          => $cmd, 
        output_files                 => [$sam_file],
        skip_if_output_is_present    => 0,
        allow_zero_size_output_files => 1, #unit test would fail if not allowing empty output samfile.
    ); 
    $self->error_message("maq2sam command: $cmd failed") and return unless $rv == 1;
    
    return 1;
}


sub create_unaligned_sam_file {
    my $self = shift;
    $self->status_message("Converting maq unaligned reads to sam format.");

    #constants for the unaligned reads conversion
    my $filler= "\t*\t0\t0\t*\t*\t0\t0\t";
    my $pair1 = "\t69";
    my $pair2 = "\t133";
    my $frag  = "\t4";
    
    my $unaligned_file = $self->unaligned_reads_list_path;
    unless (-e $unaligned_file) {
        $self->error_message("unaligned read file: $unaligned_file not existing");
        return;
    }
    
    my $unaligned_sam_file = $self->temp_scratch_directory . '/all_sequences_unaligned.sam';
 
    my $fh = Genome::Sys->open_file_for_reading($unaligned_file);
    my $ua_fh = IO::File->new(">>$unaligned_sam_file");
    unless ($ua_fh) {
        $self->error_message("Error opening unaligned sam file: $unaligned_sam_file for appending $!");
        return;
    }

    $self->status_message("Opened file for reading: $unaligned_file");
    $self->status_message("Opened file for appending: $unaligned_sam_file");
    my $count = 0;
    
    if ($self->instrument_data->is_paired_end and !$self->is_not_run_as_paired_end) {
        while (my $line1 = $fh->getline) {
            my $line2 = $fh->getline; 
            #$line1 =~ m/(^\S.*)#.*\t99\t(.*$)/;
            $line1 =~ m/(^\S.*)\t99\t(.*$)/;
            my $readName1 = $1;
            my $readData1 = $2;
            #$line2 =~ m/(^\S.*)#.*\t99\t(.*$)/;
            $line2 =~ m/(^\S.*)\t99\t(.*$)/;
            my $readName2 = $1;
            my $readData2 = $2;

            print $ua_fh $readName1.$pair1.$filler.$readData1."\n";
            print $ua_fh $readName2.$pair2.$filler.$readData2."\n";

            $count++;
        }
    } 
    else {
        while (my $line1 = $fh->getline) {
            $line1 =~ /^(\S+)\s+99\s+(.*$)/;
            my $readName1 = $1;
            my $readData1 = $2;
            print $ua_fh $readName1.$frag.$filler.$readData1."\n";
            $count++;
        }
    }

    $ua_fh->close;
    $self->status_message("Done converting unaligned reads to Sam format. $count reads processed.");
    
    return 1; 
}


sub aligner_params_for_sam_header {
    return shift->_maq_cmd;
}


sub fillmd_for_sam {
    return 1;
}

1;
