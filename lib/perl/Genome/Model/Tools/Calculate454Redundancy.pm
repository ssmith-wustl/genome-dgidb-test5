
package Genome::Model::Tools::Calculate454Redundancy;

use strict;
use warnings;

use Genome;
use Cwd;
use IO::File;
use File::Basename;
use PP::LSF;
use Data::Dumper;
use Bio::SeqIO;
use Sys::Hostname;
require File::Copy;

class Genome::Model::Tools::Calculate454Redundancy {
    is => 'Command',
    has => [
	sff_file_names => {
	    type => 'String',
	    is_optional => 1,
	    doc => 'Sff files to calculate redundancy for',
	},
	dir => {
	    type => 'String',
	    is_optional => 1,
	    doc => 'directory where this should run',
	},
	mismatch_cutoff => {
	    type => 'String',
	    is_optional => 1,
	    doc => 'Maximum number of mismatchs allowed before read is redundant',
	},
	newbler => {
	    type => 'Text',
	    is_optional => 1,
	    default_value => '/gscmnt/temp224/research/lye/rd454_mapasm_08172010/applicationsBin/runAssembly',
	    doc => 'User specified newbler to run',
	},
	screen_length => { #COULD BE NAMED BETTER
	    type => 'Number',
	    is_optional => 1,
	    doc => 'Seqment of read to run cross-match to determine redundancy',
	},
	newbler_params => {
	    type => 'String',
	    is_optional => 1,
	    doc => 'Optional params for newbler',
	},
	cross_match_jobs => {
	    type => 'Integer',
	    is_optional => 1,
	    doc => 'Number of blade jobs to run cross_match, default is 1 job per 4500 reads',
	},
	cross_match_minscore => {
	    type => 'Integer',
	    is_optional => 1,
	    default_value => 36,
	    doc => 'Minscore value to use for cross match, default is 36',
	},
	cross_match_minmatch => {
	    type => 'Integer',
	    is_optional => 1,
	    default_value => 18,
	    doc => 'Minmatch value to use for cross match, default is 18',
	},
	cross_match_masklevel => {
	    type => 'Integer',
	    is_optional => 1,
	    default_value => 101,
	    doc => 'Masklevel value to use for cross match, default is 101',
	},
	cross_match_penalty => {
	    type => 'Number',
	    is_optional => 1,
	    doc => 'Uses cross match penalty param with specified value to use',
	},
	cross_match_gap_init => {
	    type => 'Number',
	    is_optional => 1,
	    doc => 'Uses cross match gap init param with specified value to use',
	},
	cross_match_gap_ext => {
	    type => 'Number',
	    is_optional => 1,
	    doc => 'Uses cross match gap ext param with specified value to use',
	},
	save_cross_match_directory => {
	    type => 'Boolean',
	    is_optional => 1,
	    doc => 'Allow tool to save cross match run directory, warning: this uses lots of disk space',
	},
    ],
};

sub help_brief {
    'Tool to calculate redundancy in 454 data set',
}

sub help_synopsis {
    return <<"EOS"
    gmt calculate-454-redundancy --dir <DIR>
    gmt calculate-454-redundancy --dir <DIR> --sff-file-names <SFF1,SFF2,SFF3>
    gmt calculate-454-redundancy --newbler <MY_OWN_NEWBLER>
EOS
}

sub help_detail {
    return <<"EOS"
This is a tool to calculate redundancy of 454 data set.  This
is done by getting fasta from sff file, run newbler to remove linker
sequence from fasta, then run cross match on user defined bp of _left
version of the read
EOS
}

sub execute {
    my $self = shift;

    my $host = hostname();

    unless ($host =~ /blade/) {
	$self->error_message("You must run this program from a 64 bit blade platform");
	return;
    }

    #RUN NEWBLER PARTIALLY TO TRIM REMOVE LINKER FROM SFF FILE
    $self->status_message("Running newbler to create 454Trim file");
    unless ($self->_submit_newbler_to_lsf()) {
	$self->error_message("Failed to run newbler to make 454 trim file");
	return;
    }

    #GENERATE FASTA FILES FROM SFF FILES
    $self->status_message("Generating fastas from sff files");
    unless ($self->_get_fasta_from_sff_files()) {
	$self->error_message("Failed to generate fastas from sff files");
	return;
    }

    #FILTER 454TRIM FILE FOR READ POSITIONS
    my ($read_lengths, $read_counts);
    $self->status_message("Filtering 454Trim file for read positions");
    unless (($read_lengths, $read_counts) = $self->_filter_trim_file_for_read_positions()) {
	$self->error_message("Failed to filter 454Trim file for read positions");
	return;
    }

    #RUN CROSS_MATCH ON EACH FILTERED FILE
    $self->status_message("Running cross match");
    unless ($self->_farm_low_mem_cross_match()) {
	$self->error_message("Failed to run cross match");
	return;
    }

    #PARSE CROSS_MATCH REPORT FILES
    my ($dup0_reads, $dup1_reads);
    $self->status_message("Parsing cross match report files");
    unless (($dup0_reads, $dup1_reads) = $self->_parse_cross_match_report_files($read_lengths)) {
	$self->error_message("Failed to parse cross match files");
	return;
    }

    #PRINT DUPLICATE READ NAMES
    $self->status_message("Printing duplicate read names");
    unless ($self->_print_duplicate_read_names($dup0_reads, $dup1_reads)) {
	$self->error_message("Failed to print duplicate read names");
	return;
    }

    #PRINT REPORT
    $self->status_message("Printing results");
    unless ($self->_print_results($dup0_reads, $read_counts)) {
	$self->error_message("Failed to print results");
	return;
    }

    #GET DATA TO CALCULATE 454 PARIED EFFICACY
    my $paired_counts;
    $self->status_message("Calculating PE efficiency");
    unless ($paired_counts = $self->_get_pe_efficiency_data()) {
	$self->error_message("Failed to get PE efficiency data");
	return;
    }

    #PRINT PAIRED END EFFICIENCY REPORT
    $self->status_message("Printing PE efficiency");
    unless ($self->_print_PE_efficiency($paired_counts)) {
	$self->error_message("Failed to print PE efficiency");
	return;
    }

    $self->status_message("Finished");
    return 1;
}

sub _get_pe_efficiency_data {
    my $self = shift;
    my $dir = $self->_resolve_directory_path();
    my $trim_file = $dir.'/454TrimStatus.txt';
    my $counts = {};
    my $fh = IO::File->new("< $trim_file") ||
	die "Can not create file handle for $trim_file\n";
    while (my $line = $fh->getline) {
	next if $line =~ /^Accno/; #FILE HEADER
	$counts->{all_read_count}++;
	my @tmp = split(/\s+/, $line);
	#$tmp[0] = read_name
	#$tmp[2] = $read_length
	if ($tmp[0] =~ /_left$|_right$/) {
	    my $root_name = $tmp[0];
	    $root_name =~ s/_left$|_right$//;
	    if ($tmp[0] =~ /_left$/) {
		$counts->{$root_name}->{left} = $tmp[2];
	    }
	    if ($tmp[0] =~ /_right$/) {
		$counts->{$root_name}->{right} = $tmp[2];
	    }
	}
    }
    $fh->close;
    return $counts;
}

sub _print_PE_efficiency {
    my $self = shift;
    my $counts = shift;
    my $dir = $self->_resolve_directory_path();
    my $out_file = $dir.'/PE_efficiency';
    my $paired_read_count = scalar (keys %$counts);
    my $total_read_count = $counts->{all_read_count} - $paired_read_count;
    delete $counts->{all_read_count};
    my $paired_read_ratio = int ($paired_read_count / $total_read_count * 100);
    my $greater_than_50bp_count = 0;
    foreach my $pe_read (keys %$counts) {
	$greater_than_50bp_count ++ if
	    $counts->{$pe_read}->{left} > 50 and $counts->{$pe_read}->{right} > 50;
	delete $counts->{$pe_read};
    }
    my $paired_read_gt_50_ratio = int ($greater_than_50bp_count / $total_read_count * 100);
    my $fh = IO::File->new("> $out_file") ||
	die "Can not create file handle for $out_file\n";
    $fh->print("Paired end efficiency %\n");
    $fh->print("% of paired end reads = $paired_read_ratio".'%'." ($paired_read_count/$total_read_count)\n");
    $fh->print("% of paired end reads which are greater than 50 bps at both ends = $paired_read_gt_50_ratio".'%'." ($greater_than_50bp_count/$total_read_count)\n");
    $fh->close;
    return 1;
}

#DERIVES AT THE CROSS-MATCH OUT DIR NAME
sub _resolve_cross_match_dir_name {
    my $self = shift;
    my $dir = $self->_resolve_directory_path();
    my $screen_length = $self->_resolve_length_of_read_to_screen();
    my $cm_dir = $dir.'/CROSS_MATCH_'.$screen_length.'_BASES';
    return $cm_dir;
}

sub _get_cross_match_report_files {
    my $self = shift;

    my $cm_dir = $self->_resolve_cross_match_dir_name();
    unless (-d $cm_dir) {
	$self->error_message("Failed to find $cm_dir");
	return;
    }

    my @report_files = glob("$cm_dir/*crossmatch.report");
    unless (@report_files) {
	$self->error_message("Failed to find any report files in $cm_dir");
	return;
    }
    return @report_files;
}

sub _parse_cross_match_report_files {
    my $self = shift;
    my $read_lengths = shift;

    my $dup0_reads = {};
    my $dup1_reads = {};
    my $dir = $self->_resolve_directory_path();
    my $screen_length = $self->_resolve_length_of_read_to_screen();
    foreach my $report_file ($self->_get_cross_match_report_files()) {
	my $fh = IO::File->new("< $report_file") ||
	    die "Can not create file handle for $report_file\n";
	$self->status_message("\tParsing ".basename($report_file));
	while (my $line = $fh->getline) {
	    next unless $line =~ /^ALIGNMENT\s+/;
	    my @tmp = split(/\s+/, $line);
	    
	    #LINE EXAMPLE
	    #$tmp[0]      1   2    3    4     5                          6    7  8      9                          10   11 12
	    #ALIGNMENT    75  0.00 0.00 0.00  FGUJOYO02TW4FG_left        1    75 (0)    FGUJOYO02PHARU_left        1    75 (0)
	    #ALIGNMENT    70  0.00 1.35 0.00  FGUJOYO02PYMJH_left        1    74 (1)    FGUJOYO02PX6P9_left        1    75 (0)
	    
	    #$tmp[5]  = query read name
	    #$tmp[9]  = subject read name
	    #$tmp[2]  = mismatch
	    #$tmp[6]  = source match start
	    #$tmp[7]  = source match stop
	    #$tmp[10] = target match start
	    #$tmp[11] = target match stop

	    #SKIP INTRA HITS
	    next if $tmp[9] eq 'C';
	    next if $tmp[5] eq $tmp[9];

	    #SKIP UNLESS QUERY AND SUBJECT ARE THE SAME LENGTH
	    my ($orig_query_name) = $tmp[5] =~ /(\S+)_left/;
	    my ($orig_subject_name) = $tmp[9] =~ /(\S+)_left/;
	    unless (exists $read_lengths->{$orig_query_name} && exists $read_lengths->{$orig_subject_name}) {
		$self->error_message("Failed to get original query or suject name for $tmp[5] or $tmp[9]");
		return;
	    }
	    next unless ($read_lengths->{$orig_query_name} == $read_lengths->{$orig_subject_name});
	    
	    #ADDING UP ALL THE GAPS
	    #GAP HERE IS REALLY TOTAL NUMBER OF BASES THAT DON'T MATCH
	    #IF TWO 75 BP SEQ ALIGN AT 45-75 TO 1-30 THAT LEAVES
	    #60 TOTAL BASES THAT ALIGN AND 90 BASES THAT DON'T .. GAP HERE IS THE 90 BASES
	    
	    my $gap = abs(($tmp[6] - $tmp[7]) - ($tmp[10] - $tmp[11]));
	    $gap += (&get_max_or_min_value($tmp[7],$tmp[11],'max')) - (&get_max_or_min_value($tmp[7],$tmp[11],'min'));
	    $gap += (&get_max_or_min_value($tmp[6],$tmp[10],'max')) - (&get_max_or_min_value($tmp[6],$tmp[10],'min'));
	    
	    #ADDING UP MISMATCHES .. NOT REALLY SURE WHAT THE LOGIC HERE IS
	
	    my $mismatch = int(($tmp[7] - $tmp[6] + 1) * $tmp[2]/100 + 0.5);
	    $mismatch += &get_max_or_min_value($tmp[6],$tmp[10],'min') - 1;
	    $mismatch += $screen_length - &get_max_or_min_value($tmp[7],$tmp[11],'max');
	    
	    my $mismatch_cutoff = ($self->mismatch_cutoff) ? $self->mismatch_cutoff : 0;

	    my ($sff_prefix) = $tmp[5] =~ /^(\w{9})/;
	    
	    if ($mismatch <= $mismatch_cutoff) {
		if ($gap == 0) {
		    $dup0_reads->{$sff_prefix}->{$tmp[5]} = 1;
		}
		if ($gap == 1) {# TAKE OUT .. THIS CAN NEVER == 1
		    $dup1_reads->{$sff_prefix}->{$tmp[5]} = 1;
		}
	    }
	}
	$fh->close;
    }
    undef $read_lengths;

    #REMOVE CROSS_MATCH DIR
    unless ( $self->save_cross_match_directory ) {
	my $cm_dir = $dir.'/CROSS_MATCH_'.$screen_length.'_BASES';
	unless (File::Path::rmtree($cm_dir)) {
	    $self->status_message("Failed to remove cross_match dir");
	}
    }
    return $dup0_reads, $dup1_reads;
}

sub _print_results {
    my $self = shift;
    my $dup0_reads = shift;
    my $read_counts = shift;

    my $dir = $self->_resolve_directory_path();

    sleep(30);

    my $total_count = 0; #TOTAL OF ALL REDUNDANT READS IN ALL SETS
    my $result_file = $dir.'/results.75dup0';
    my $fh = IO::File->new("> $result_file") ||
	die "Can not create file handle for $result_file\n";
    $fh->printf("%-15s%-30s%-30s\n", 'SET', 'INDIVIDUAL', 'COMBINED');
    foreach my $sff_set (sort keys %$dup0_reads) {
	my $count = scalar (keys %{$dup0_reads->{$sff_set}});
	$total_count += $count;
	my $individual_rate = sprintf("%.2f", $count / $read_counts->{$sff_set} * 100);
	my $combined_rate = sprintf("%.2f", $count / $read_counts->{combined} * 100);
	my $ind_string = $count.'/'.$read_counts->{$sff_set}.'('.$individual_rate.')';
	my $com_string = $count.'/'.$read_counts->{combined}.'('.$combined_rate.')';
	$fh->printf("%-15s%-30s%-30s\n", $sff_set, $ind_string, $com_string);
    }
    my $total_combined = sprintf("%.2f", $total_count / $read_counts->{combined} * 100);
    my $total_combined_string = $total_count.'/'.$read_counts->{combined}.'('.$total_combined.')';
    $fh->printf("%-45s%-30s\n", 'TOTAL', $total_combined_string);
    $fh->close;
    return 1;
}

sub get_max_or_min_value {
    my ($val1, $val2, $condition) = @_;
    my $return_value;
    if($condition eq 'max') {
	return $val1 if $val1 >= $val2;
	return $val2 if $val2 >= $val1;
    }
    else {
	return $val1 if $val1 <= $val2;
	return $val2 if $val2 <= $val1;
    }
    return;
}

sub _print_duplicate_read_names {
    my $self = shift;
    my $dup0_reads = shift;
    my $dup1_reads = shift;

    my $dir = $self->_resolve_directory_path();
    my $screen_length = $self->_resolve_length_of_read_to_screen();

    my $c = 0;
    foreach my $reads_h ($dup0_reads, $dup1_reads) {
	foreach my $sff_prefix (sort keys %$reads_h) {
	    my $file_name = $dir.'/'.$sff_prefix.'.'.$screen_length.'dup'.$c;
	    my $fh = IO::File->new("> $file_name") ||
		die "Can not create file handle for $file_name\n";
	    foreach (keys %{$reads_h->{$sff_prefix}}) {
		$fh->print("$_\n");
	    }
	    $fh->close;
	}
	$c++;
    }

    return 1;
}

sub _farm_low_mem_cross_match {
    my $self = shift;
    my $dir = $self->_resolve_directory_path();

    #NUMBER OF BASES TO USE TO RUN CROSS-MATCH FROM EACH READ
    my $screen_length = $self->_resolve_length_of_read_to_screen();

    #CHECK FOR CROSS-MATCH INPUT FILE
    my $query_file = $dir.'/READS_TO_SCREEN.pre'.$screen_length.'fna';;
    unless (-s $query_file) {
	$self->error_message("Failed to find $query_file");
	return;
    }

    #DEFINE DIRECTORY TO PUT CROSS-MATCH OUTPUT FILES IN
    my $out_dir = $dir.'/CROSS_MATCH_'.$screen_length.'_BASES';
    if (-d $out_dir) {
	unless (File::Path::rmtree($out_dir)) {
	    $self->error_message("Unable to remove exists cross_match dir: $out_dir");
	    return;
	}
    }

    my $jobs = ( $self->cross_match_jobs ) ? $self->cross_match_jobs : $self->_get_cm_jobs_by_number_of_reads( $query_file );
    my $min_score = $self->cross_match_minscore;
    my $min_match = $self->cross_match_minmatch;
    my $mask_level = $self->cross_match_masklevel;

    #RUN CROSS-MATCH params
    my $cmd = "/gscmnt/233/info/seqana/scripts/BLADE_CROSSMATCH_for_454_redundancy.pl -outdir $out_dir -q $query_file -s $query_file -b $jobs  -a ";
    #blade cross match params
    my $param = "\"-raw -tags -minscore $min_score -minmatch $min_match -gap1_only -masklevel $mask_level";
    $param .= ' -penalty '. $self->cross_match_penalty if $self->cross_match_penalty;
    $param .= ' -gap_init '.$self->cross_match_gap_init if $self->cross_match_gap_init;
    $param .= ' -gap_ext '. $self->cross_match_gap_ext if $self->cross_match_gap_ext;
    $param .= "\"";
    $cmd = $cmd.$param;
    $self->status_message("Running BLADE_CROSSMATCH with command: $cmd");
    if (system($cmd)) { #MAKE SURE CORRECT VALUE IS RETURNED HERE
	$self->error_message("Failed to run cross_match");
	return;
    }

    #check to see if all jobs succeeded
    my $file_count = 0;         #total number of reports == number of jobs
    my $done_report_count = 0;  #number of succeeded jobs
    for my $report_file ( glob("$out_dir/*report") ) {
	$file_count++;
	my $out = `tail $report_file`;
	$done_report_count++ if $out =~ /Times\s+in\s+secs\s+\(/;
    }
    unless ( $file_count == $jobs and $done_report_count == $jobs ) {
	$self->error_message("Some of cross match jobs failed: $file_count reports with $done_report_count reports done. Expected $jobs total number of reports");
	return;
    }
    
    $self->status_message("All cross match jobs completed successfully");

    return 1;
}

#DETERMINE HOW MANY BASES TO USE FOR CROSS-MATCH
sub _resolve_length_of_read_to_screen {
    my $self = shift;
    #DEFAULT LENGTH IS 75 BASES
    return 75 unless $self->screen_length;
    my $screen_length;
    if ($self->screen_length) {
	unless ($self->screen_length =~ /^\d+$/ && $self->screen_length >= 50) {
	    $self->error_message("screen_length must be a number greater than 50");
	    return;
	}
    }
    return $self->screen_length;
}

#FILTER .. COMMENT
sub _filter_trim_file_for_read_positions {
    my $self = shift;

    my $dir = $self->_resolve_directory_path();

    #TRIM FILE IS A PRODUCT OF NEWBLER RUN IN THE PREV STEP
    my $trim_file = $dir.'/454TrimStatus.txt';
    unless (-s $trim_file) {
	$self->error_message("Failed to find 454TrimStatus.txt file");
	return;
    }

    #NUMBER OF BASES TO USE TO RUN CROSS-MATCH
    my $screen_length = $self->_resolve_length_of_read_to_screen();

    #CREATE INPUT QUERY FILE FOR RUNNING CROSS-MATCH
    #SHOULD CONTAIN $SCREEN_LENGTH BASES OF _LEFT VERSION OF READS
    #FOUND IN 454 TRIM FILE FOR SPECIFIED OR ALL SFF FILE

    my $all_filtered_seq_file = $dir.'/READS_TO_SCREEN.pre'.$screen_length.'fna';
    my $filtered_seq_fh = IO::File->new("> $all_filtered_seq_file") || die
	"Can not create file handle to write all filtered sequence\n";

    #ITERATING THROUGH 454 TRIM FILE .. ONCE FOR EACH SFF FILE ..
    #MULTIPLE TIMES BUT WILL REDUCE MEMORY FOOTPRINT
    my $read_lengths = {};
    my $read_counts;
    foreach my $sff_file ($self->_resolve_sff_files_to_get()) {
	my $sff_file_name = File::Basename::basename($sff_file);
	my ($sff_root_name) = $sff_file_name =~ /^(\S+)\.sff/;
	#HASH TO KEEP TRACK OF READS WE WANT AND READ LENGTHS WHICH IS
	#NEEDED LATER
	my $fh = IO::File->new("< $trim_file") ||
	    die "Can not create file handle for 454TrimStatus file\n";
	while (my $line = $fh->getline) {
	    chomp $line;
	    my @tmp = split(/\s+/, $line);
	    my $read_name = $tmp[0];
	    #GET _LEFT READS ONLY FROM 454 TRIM FILE
	    next unless ($read_name =~ /^$sff_root_name/ && $read_name =~ /_left$/);
	    #GET START, STOP, OFFSET READS POS FROM 454TRIM FILE
	    my ($start, $stop) = $tmp[1] =~ /(\d+)-(\d+)/;
	    my $read_length = $stop - $start + 1;
	    next unless $read_length >= $screen_length;
	    #CREATE HASH OF READ_NAME->READ_LENGTH FOR
	    #LATER LOOK UP
	    $read_name =~ s/_left$//;
	    $read_lengths->{$read_name} = $read_length;
	    #KEEPING TAB OF NUMBER OF READS FOR EACH SFF FILE
	    $read_counts->{$sff_root_name}++;
	    $read_counts->{combined}++;
	}
	$fh->close;
	#FIGURE OUT THE NAME OF SFF FASTA FILE
	my $sff_fa_file = $dir.'/'.$sff_root_name.'.fna';
	unless (-s $sff_fa_file) {
	    $self->error_message("Failed to find fasta of $sff_file_name");
	    return;
	}
	#ITERATE THROUGH SFF FASTA FILE AND GET READS FOUND IN 454TRIM FILE
	#AND GET APPROPRIATE SUBSTRING OF THE SEQUENCE TO RUN CROSS-MATCH
	my $io = Bio::SeqIO->new(-file => $sff_fa_file, -format => 'fasta');
	while (my $seq = $io->next_seq) {
	    next unless exists $read_lengths->{$seq->primary_id};
	    my $read_name = $seq->primary_id.'_left';
	    my $read_length = $read_lengths->{$seq->primary_id};
	    #delete $read_lengths->{$seq->primary_id};
	    my $sub_seq = substr($seq->seq, 0, $screen_length);
	    $filtered_seq_fh->print(">$read_name $read_length\n$sub_seq\n");
	}
	unlink $sff_fa_file;
    }
    $filtered_seq_fh->close;
    
    return $read_lengths, $read_counts;
}

#RUN SFFINFO TO GENERATE FASTA FROM SFF FILE
sub _get_fasta_from_sff_files {
    my $self = shift;
    my $dir = $self->_resolve_directory_path();
    foreach my $sff_file ($self->_resolve_sff_files_to_get()) {
	my $sff_file_name = File::Basename::basename($sff_file);
	my ($sff_root_name) = $sff_file_name =~ /(\S+)\.sff$/;
	my $fasta_out = $dir.'/'.$sff_root_name.'.fna';
	#REMOVE FASTA IF ONE ALREADY EXISTS
	unlink $fasta_out if -s $fasta_out;
	$self->status_message("\tRunning sffinfo for $sff_file_name");
	if (system('sffinfo -s '.$sff_file.' > '.$fasta_out)) {
	    $self->error_message("Failed to execute command: sffinfo $sff_file");
	    return;
	}
    }
    return 1;
}

sub _submit_newbler_to_lsf {
    my $self = shift;
    #RESOLVE SFF FILES TO RUN NEWBLER ON
    my @sff_files;
    unless (@sff_files = $self->_resolve_sff_files_to_get()) {
	$self->error_message("Failed to get sff files");
	return;
    }
    my $sff_files_string; #STRING OF SFF FILES TO FEED INTO NEWBLER
    foreach (@sff_files) {
	$sff_files_string .= " $_";
    }
    #RESOLVE DIR TO RUN NEWBLER IN
    my $dir = $self->_resolve_directory_path();
    my $newb_run_dir = $dir.'/temp_newbler_run';
    #MAKE SURE WE DON'T PICK UP AN EXISTING NEWBLER RUN
    if (-d $newb_run_dir) {
	$self->error_message("Newbler run dir already exists and must be removed:\n$newb_run_dir");
	return;
    }
    #RESOLVE NEWBLER VERSION TO RUN .. USER SPECIFIED OR INSTALLED?
    if ($self->newbler) {
	unless (-s $self->newbler) {
	    $self->error_message("Can not find user specified newbler software: ".$self->newbler);
	    return;
	}
    }

    #my $version_newbler = ($self->newbler) ? $self->newbler : 'runAssembly';
    my $version_newbler = $self->newbler;
    unless ( -x $version_newbler ) {
	$self->error_message("Failed to find version of newbler or version is to executable: " . $self->newbler);
	return;
    }
    #SUBMIT JOB TO 
    my $cmd = "$version_newbler -o $newb_run_dir -cpu 1 ";
    if ($self->newbler_params) {
	$cmd .= $self->newbler_params;
    }
    $cmd .= ' '.$sff_files_string;
    $self->status_message("Running newbler with command: $cmd");
    my $job_id = 'NwB'.$$;
    my $job = PP::LSF->run(
	pp_type => "lsf",
	command => $cmd,
	J => "$job_id",
	q => 'short',
        R => "'select[type==LINUX64] span[hosts=1]'",
    );
    unless ($job) {
	$self->error_message("Failed to submit newbler run to lsf");
	return;
    }
    #CHECK FOR TRIM FILE CREATE COMPLETION
    my $trim_file = $newb_run_dir.'/assembly/454TrimStatus.txt';
    my $previous_file_size = 0;
    while (1) {
	sleep 120;
	my $file_size = 0;
	if (-s $trim_file) {
	    $file_size = -s $trim_file;
	    if ($file_size == $previous_file_size) {
		print "\tTrim file created .. stopping newbler job .. ";
		last;
	    }
	}
	$previous_file_size = $file_size;
    }
    #KILL NEWBLER .. NOT SURE IF THIS IS BAD
    my $job_found = 0;
    my @bjobs = `bjobs`;
    foreach my $line (@bjobs) {
	my @tmp = split (/\s+/, $line);
	if ($tmp[6] eq $job_id) {
	    if (system("bkill $tmp[0]")) {
		print "Failed to kill job .. kill job id is $tmp[0]\n";
	    }
	    $job_found = 1;
	}
    }
    unless ($job_found) {
	$self->error_message("Failed to find newbler job in the lsf");
	return;
    }
    #MOVE TRIM FILE TO MAIN DIRECTORY AND REMOVE NEWBLER RUN DIR
    unlink $dir.'/454TrimStatus.txt' if -s $dir.'/454TrimStatus.txt';
    unless (File::Copy::copy($trim_file, $dir.'/454TrimStatus.txt')) {
	$self->error_message("Failed to copy 454Trim file to $dir");
	return;
    }
    unless (File::Path::rmtree($newb_run_dir)) {
	$self->status_message("Failed to remove newbler run dir");
    }

    return 1;
}

sub _resolve_directory_path {
    my $self = shift;

    my $dir = ($self->dir) ? $self->dir : cwd();
    unless (-d $dir) {
	$self->error_message("Invalid directory specified:\n$dir");
	return;
    }

    return $dir;
}

#RETURN ARRAY OF DIR/SFF_FILE_NAMES
sub _resolve_sff_files_to_get {
    my $self = shift;
    my @sffs;
    my $dir = $self->_resolve_directory_path();
    #USER INPUTED SFF FILES
    if ($self->sff_file_names) {
	my @tmp = split(',', $self->sff_file_names);
	#MAKE SURE THERE ARENT ANY DUPLICATE SFF FILES
	foreach my $sff_file_name (@tmp) {
	    my @ar = grep (/^$sff_file_name$/, @tmp);
	    $self->error_message("$sff_file_name is duplicated in command line input") and return if
		@ar > 1;
	}
	@sffs = map {$dir.'/'.$_} @tmp;
    }
    #USER DID NOT SPECIFIY SFF FILES GRAB ALL SFF FILES IN DIR
    else {
	@sffs = glob("$dir/*sff");
    }
    unless (@sffs) {
	$self->error_message("No sff files found in $dir");
	return;
    }
    #VALIDATE SFF FILES
    foreach my $sff_file (@sffs) {
	unless (-s $sff_file) {
	    $self->error_message("Can find or zero size sff file: $sff_file");
	    return;
	}
    }

    return @sffs;
}

sub _get_cm_jobs_by_number_of_reads {
    my ($self, $file) = @_;

    my $c = 0;
    my $io = Bio::SeqIO->new(-format => 'fasta', -file => $file);

    while (my $seq = $io->next_seq) {
	$c++;
    }
    #run 1 job for each 4500 reads
    my $number_of_jobs = int( $c / 4500 );

    return $number_of_jobs;
}

1;
