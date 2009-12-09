
package Genome::Model::Tools::ViromeEvent::SplitBasedOnBarCode;

use strict;
use warnings;

use Genome;
use Workflow;
use Data::Dumper;
use IO::File;
use File::Basename;
use Bio::SeqIO;
class Genome::Model::Tools::ViromeEvent::SplitBasedOnBarCode{
    is => 'Genome::Model::Tools::ViromeEvent',
    has =>
    [
     barcode_file => {
	 doc => 'file of reads to be checked for contamination',
	 is => 'String',
	 is_input => 1,
     },
     fasta_file => {
	 doc => 'file of reads to be checked for contamination',
	 is => 'String',
	 is_input => 1,
     },
    ],
};

sub help_brief {
    return <<"EOS"
Creates a list of directories and fasta files based on querying barcode file against fasta file
EOS
}

sub help_synopsis {
    return <<"EOS"
genome-model toold virome-event split-based-on-bar-code
EOS
}

sub help_detail {
    return <<"EOS"
This script accepts a 454 sequencing run output fasta file and sort the 
sequences based on their barcode. Each group of barcoded sequence 
represents a library. A "undecodable" file/dir will be created for 
sequences that do not have exact match to any of the used barcode.
One directory will be created for each library, which will hold a .fa file
holding all the sequences from this library.

In this version, primer B sequence at both ends were stripped off, check for
number of samples, duplication of primer B sequence.

In this version, calculate percentage of sequences in each length category
0-50, 51 - 100 etc.

In this version, both barcodes from 5 prime and 3 prime are used for 
decoding.

<barcode file> = full path to the file
<fasta file> = 454 .fa sequence file with full path 
                   This script will create directories in the dir that the
                   input file resides. 
<logfile>   = output file for logging events
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;

}

sub execute {
    my $self = shift;

    my ($input_file, $barcode_seq_file) = ($self->fasta_file, $self->barcode_file);

    $self->log_event("Splitting $input_file based on barcode...");
    my $output_dir = $self->dir;
    
    my $lib_name = basename($output_dir);
    $self->log_event("lib is $lib_name");
    my $out = $output_dir."/"."Analysis_ReadStatistics_".$lib_name;

    my $analysis_fh = IO::File->new("> $out") ||
	die "Can not create file handle for $out";

    # cutoffs for sample to be reamplify and resequencing TODO ???
    my $percentage_cutoff = 15; # percentage of sequence less than 100 bp
    my $numOfSeq_cutoff = 5000;	# total number of reads
    my %resequencing = ();
    my $C = "#######################################################\n";

    my $count_decoded = 0;
    my $count_have_noPB = 0;
    my $count_have_5primePB = 0;
    my $count_have_3primePB = 0;
    my $count_have_PB_both_end = 0;
    my $count_total = 0;
    my $have_3primePB_decoded_by_3prime = 0;
    my $have_PB_both_end_decoded_by_5prime = 0;
    my $have_PB_both_end_decoded_by_3prime = 0;

    my $total_length_run = 0; # total length of all sequences in the run
    my @bin = ();
    my $range = 50;
    my $numBin = 8;
    my @LengthOfSequences = (); # length of sequences

    # Given one output file from 454 sequencing (assume one fasta file
    # with a pool of sample libraries each with a unique tag).
    # Split this one fasta file into different .fa files based on perfect 
    # match to barcode sequence.

    # read in barcode sequence used in the given run
    my $PBseq ="GTTTCCCAGTCACGATA";
    my $PB_ReverseComplement = $PBseq;
    $PB_ReverseComplement = reverse $PB_ReverseComplement;
    $PB_ReverseComplement =~ tr/ACGTacgt/TGCAtgca/;

    my %barcode = (); # barcode_sequence => library name
    my $barcode_length = 0;
    my $total_sample = 0;
    my $barcode_fh = IO::File->new("< $barcode_seq_file") ||
	die "Can not create file handle for $barcode_seq_file";
    while (my $line = $barcode_fh->getline) {
	next if $line =~ /^\s+$/ || $line =~ /#/;
	chomp $line;
	my @temp = split(/\s+/, $line);
	my $sample_number = $temp[0];
	#?? $temp[1] ?? 
	my $tag = $temp[2]; #BARCODE SEQUENCE
        my $lib = $temp[3]; #LIBRARY NAME
	$tag =~ s/$PBseq//;
	next unless $tag; #SKIP IF TAG SEQ IS COMPOSED ENTIRELY OF PB SEQ
	$lib =~ s/\W+/_/g;
	my $samp_name = "S".$sample_number."_".$lib;
	$self->log_event("tag = $tag, samp_name =$samp_name");
	if (defined $barcode{$tag}) {
		$analysis_fh->print("$tag => $barcode{$tag} is duplicated! $samp_name\n");
	}
	else {
		$barcode{$tag} = $samp_name;
		$total_sample++;
	}
	$barcode_length = length($tag);
    }
    $barcode_fh->close;

    my %barcoded_seq = (); # barcode => read_name => read_sequence

    my $io = Bio::SeqIO->new(-format => 'fasta', -file => $input_file);
    while (my $seq = $io->next_seq) {
	$count_total++;
	my $read_name = $seq->primary_id;
	my $read_seq = $seq->seq;

	push @LengthOfSequences, length($read_seq);
	$total_length_run += length($read_seq);
	
	my $found_5primePB = 0;
	my $found_3primePB = 0;
	my $final_seq = $read_seq; 
	my $code = "";
	my $decoded = 0;
	my $before_5primePB = "";
	if ($final_seq =~ /$PBseq/) {
	    $found_5primePB = 1;
	    $before_5primePB = "$`";
	    $final_seq = "$'";
	}

	# find 3' primer B
	my $after_3primePB = "";
	if ($final_seq =~ /$PB_ReverseComplement/) {
	    $found_3primePB = 1;
	    $final_seq = "$`";
	    $after_3primePB = "$'";
	}

	my $presumecode_5prime = substr($before_5primePB, -1*$barcode_length);
	my $presumecode_3prime = substr($after_3primePB, 0, $barcode_length);
	
	if ($found_5primePB && $found_3primePB) {
	    $count_have_PB_both_end++;
	    if (defined $barcode{$presumecode_5prime}) {
		$count_decoded++;
		$decoded = 1;
		$have_PB_both_end_decoded_by_5prime++;
		$code = $presumecode_5prime;
	    }
	    else { # could not decode use 5' barcode, check 3' sequence
		# calculate reverse complement of 3' presume code
		my $RC = $presumecode_3prime;
		$RC = reverse $RC;
		$RC =~ tr/ACGTacgt/TGCAtgca/;
		
		if (defined $barcode{$RC}) {
		    $decoded = 1;
		    $count_decoded++;
		    $have_PB_both_end_decoded_by_3prime++;
		    $code = $RC;
		}
	    }
	}
	elsif ($found_5primePB) {
	    $count_have_5primePB++;
	    if (defined $barcode{$presumecode_5prime}) {
		$count_decoded++;
		$decoded = 1;
		$code = $presumecode_5prime;
	    }
	}
	elsif ($found_3primePB) {
	    $count_have_3primePB++;
	    # calculate reverse complement of 3' presume code
	    my $RC = $presumecode_3prime;
	    $RC = reverse $RC;
	    $RC =~ tr/ACGTacgt/TGCAtgca/;
	    if (defined $barcode{$RC}) {
		$decoded = 1;
		$count_decoded++;
		$have_3primePB_decoded_by_3prime++;
		$code = $RC;
	    }
	}
	else {
	    $count_have_noPB++;
	}
	
	if ($decoded) {
	    $barcoded_seq{$code}{$read_name} = $final_seq;
	}
	else { # could not find corresponding barcode
	    $barcoded_seq{"undecodable"}{$read_name} = $final_seq;
	}
    }

    # foreach barcode, generate one output file which holds all sequences 
    # that have that barcode. Each barcode represents one library.

    foreach my $code_seq (keys %barcoded_seq) {
	my $samp_name = ($code_seq eq 'undecodable') ? $lib_name.'_undecodable' : $barcode{$code_seq};
	my $samp_dir = $output_dir.'/'.$samp_name;
	unless (-d $samp_dir) {
	    system("mkdir $samp_dir");
	}
	unless (-d $samp_dir) {
	    $self->log_event("Failed to create sample directory for ".basename($samp_dir));
	    return;
	}
	my $outFile = $output_dir.'/'.$samp_name.'/'.$samp_name.".fa";
	my $fa_out = IO::File->new("> $outFile") ||
	    die "Can not create file handle for $outFile";
	foreach my $read_name (keys %{$barcoded_seq{$code_seq}}) {
	    $fa_out->print(">$read_name\n");
	    $fa_out->print("$barcoded_seq{$code_seq}{$read_name}\n");
	}
	$fa_out->close;
    }
    
    $analysis_fh->print("\n$input_file\n".
			"total number of samples: $total_sample\n".
			"total number of sequences: $count_total\n");
    $analysis_fh->printf("number of sequences have no PB: %d \( %5.1f%% \)\n", $count_have_noPB, $count_have_noPB*100/$count_total);
    $analysis_fh->printf("number of sequences have 5 prime PB: %d \( %5.1f%% \)\n", $count_have_5primePB, $count_have_5primePB*100/$count_total);
    
    #TO AVOID DIVISION BY ZERO ERROR
    my $have_3primePB_decoded = ($count_have_5primePB > 0) ? $have_3primePB_decoded_by_3prime*100/$count_have_3primePB : 0;
	
    $analysis_fh->printf("number of sequences have 3 prime PB: %d\( %5.1f%% \), number of seq decoded by 3' code %d, \( %5.1f%% \) \n", $count_have_3primePB, $count_have_3primePB*100/$count_total, $have_3primePB_decoded_by_3prime, $have_3primePB_decoded);

    #TO AVOID DIVISION BY ZERO ERRORS
    my $have_PB_both_end_decoded_by_5prime_ratio = ($count_have_PB_both_end) ? $have_PB_both_end_decoded_by_5prime*100/$count_have_PB_both_end : 0;
    my $have_PB_both_end_decoded_by_3prime_ratio = ($count_have_PB_both_end) ? $have_PB_both_end_decoded_by_3prime*100/$count_have_PB_both_end : 0;

    $analysis_fh->printf("number of seq have PB at both ends: %d \( %5.1f%% \), number of seq decoded by 5' code: %d \( %5.1f%% \), number of seq decoded by 3' code: %d \( %5.1f%% \)\n", $count_have_PB_both_end, $count_have_PB_both_end*100/$count_total, $have_PB_both_end_decoded_by_5prime, $have_PB_both_end_decoded_by_5prime_ratio, $have_PB_both_end_decoded_by_3prime, $have_PB_both_end_decoded_by_3prime_ratio);

    $analysis_fh->printf("number of sequences decoded: %d\(%5.1f%%\)\n", $count_decoded, $count_decoded*100/$count_total);
    $analysis_fh->printf("%s%d\n\n", "average length of sequence: ", $total_length_run/$count_total);

    my @disRun = ();
    &calculate_disbribution(\@LengthOfSequences, $range, $numBin, \@disRun);
    $analysis_fh->print("$C"."distribution of sequence length in the run:\n");
    $analysis_fh->printf("%6s%10s%10s", "barcode", "total#", "AveLen"); 
    for (my $i = 0; $i <= $numBin; $i++) {
        $analysis_fh->printf("%7d", $i*$range);
    }
    $analysis_fh->print(" sample\n");

    $analysis_fh->printf("%6s%10d%10d", "total", $count_total, $total_length_run/$count_total);
    for (my $i = 0; $i <= $numBin; $i++) {
	$analysis_fh->printf("%7.1f", $disRun[$i]*100/$count_total);
    }

    # foreach barcode, calculate the statistics and output information 
    # if a sample has less than $total_seq_cutoff total sequence, or has 
    # less than $unique_seq_cu
    my @bad_samples = ();
    my %sequence_stat = (); # sample name => sequence statistics

    foreach my $code_seq (sort {$a cmp $b} keys %barcoded_seq) {

    next if $code_seq =~ /undecod/;

    my $shortest_len = 10000;
    my $longest_len = 0;
    my $total_length_sample = 0;
    my $numOfSeq = 0;
    my @lengthSample = ();
    
    foreach my $read_name (keys %{$barcoded_seq{$code_seq}}) {
	$numOfSeq++;
	my $length = length($barcoded_seq{$code_seq}{$read_name});
	$total_length_sample += $length;
	push @lengthSample, $length;
	if ($length < $shortest_len) {
	    $shortest_len = $length;
	}
	if ($length > $longest_len) {
	    $longest_len = $length;
	}
	
    }
	
    # output information
    my $ave_len = $total_length_sample/$numOfSeq;
    my @dis_sample = ();
    &calculate_disbribution(\@lengthSample, $range, $numBin, \@dis_sample);
    my $info = sprintf ("%6s%10d%10d", $code_seq, $numOfSeq, $ave_len,);
    my $lessThan100 = 0;
    for (my $i = 0; $i <= $numBin; $i++) {
	my $ptg = $dis_sample[$i]*100/$numOfSeq;
	$info .= sprintf ("%7.1f", $ptg );
	if ($i == 0 || $i == 1) {
	    $lessThan100 += $ptg;
	}
    }
    $info .= sprintf "  ";
    $info .= sprintf $barcode{$code_seq}, "\n";
    
    if ($lessThan100 >= $percentage_cutoff) {
	$resequencing{$barcode{$code_seq}} = 1;
    }
    if ($numOfSeq <= $numOfSeq_cutoff) {
	$resequencing{$barcode{$code_seq}} = 1;
    }
    $sequence_stat{$barcode{$code_seq}} = $info;
    }
    
    foreach my $sample (sort {$a cmp $b} keys %sequence_stat) {
	$analysis_fh->print("\n".$sequence_stat{$sample}."\n");
    }
    $analysis_fh->print ("End of Distribution\n\n"."$C"."Sample needs to be reamplified:\n");
    foreach my $spl (sort {$a cmp $b} keys %resequencing) {
	$analysis_fh->print($spl, "\n");
    }
    $analysis_fh->print("End of sample list\n");
    $analysis_fh->close;
    $self->log_event("Split based on barcode completed"); #monitor
    return 1;
}


#####################################################################
# This subroutine accepts an array of numbers and the range for a bin
# and calculate the distribution of number at each range
sub calculate_disbribution {
    my ($data_arr, $range, $numBin, $dis_arr) = @_;
    
    for (my $i = 0; $i <= $numBin; $i++) {	
        $dis_arr->[$i] = 0;
    }
    
    foreach my $num (@{$data_arr}) {
        my $bin = int($num/$range);
      	if ($bin < $numBin) {
	    $dis_arr->[$bin]++;
	}	
	else {
	    $dis_arr->[$numBin]++;
	}
    }
}

1;

sub sub_command_sort_position { 7 }
