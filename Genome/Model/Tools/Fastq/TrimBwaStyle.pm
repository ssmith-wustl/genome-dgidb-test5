package Genome::Model::Tools::Fastq::TrimBwaStyle;

#Adapting from TrimBwaStyle.pl

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::Fastq::TrimBwaStyle {
    is  => 'Command',
    has_input => [
        fastq_file  => {
            is  => 'Text',
            doc => 'the input fastq file path',
        }, 
        out_file    => {
            is  => 'Text',
            doc => 'the file path of the output file, default is xxx.trimmed.fastq in fastq_file dir',
            is_optional => 1,
        },
        trim_qual_level => {
            is  => 'Integer',
            doc => 'trim quality level',
            default => 10,
            is_optional => 1,
        },
        qual_type   => {
            is  => 'Text',
            doc => 'The fastq quality type, must be either sanger(Qphred+33) or illumina(Qphred+64)',
            valid_values  => ['sanger', 'illumina'],
            default_value => 'sanger',
            is_optional   => 1,
        },
        report_file => {
            is  => 'Text',
            doc => 'the file path of the trim report file, default is trim.report in the same dir as out_file',
            is_optional => 1,
        },
    ],
};

sub help_synopsis {
    return <<EOS
gmt fastq trim-bwa-style --fastq-file=lane1.fastq --out-file=lane1.trimmed.fastq
EOS
}

sub help_detail {
    return <<EOS 
Trims fastq reads with BWA trimming style aka bwa aln -q
EOS
}


sub execute {
    my $self = shift;
        
    my $fastq_file = $self->fastq_file;
    unless ($fastq_file and -s $fastq_file) {
        $self->error_message("Fastq file : $fastq_file is not valid");
        return;
    }

    my ($base_name, $base_dir) = fileparse($fastq_file);
    $base_name =~ s/\.fastq$// if $base_name =~ /\.fastq$/;

    my $out_file = $self->out_file || $base_dir."/$base_name.trimmed.fastq";
    my $out_dir = dirname $out_file;
    $self->out_file($out_file);
    
    if (-e $out_file) {
        $self->warning_message("Out file: $out_file existing. Overwrite it");
        unlink $out_file;
    }
    
    my $report = $self->report_file || $out_dir . '/trim.report';
    if (-e $report) {
        $self->warning_message("Reprot file: $report existing. Overwrite it");
        unlink $report;
    }

    my $input_fh  = Genome::Utility::FileSystem->open_file_for_reading($fastq_file);
    unless ($input_fh) {
        $self->error_message('Failed to open fastq file ' . $fastq_file . ": $!");
        return;
    }
    binmode $input_fh, ":utf8";

    my $output_fh = Genome::Utility::FileSystem->open_file_for_writing($out_file);
    unless ($output_fh) {
        $self->error_message('Failed to open output file ' . $out_file . ": $!");
        return;
    }
    binmode $output_fh, ":utf8";

    my $report_fh = Genome::Utility::FileSystem->open_file_for_writing($report);
    unless ($report_fh) {
        $self->error_message("Failed to open report file " . $report . ": $!");
        return;
    }
    binmode $report_fh, ":utf8";
    
    my ($qual_str, $qual_thresh) = $self->qual_type eq 'sanger' ? ('#', 33) : ('B', 64);
    
    my $ori_ct     = 0;
    my $trim_ct    = 0;
    my $rd_ori_ct  = 0;
    my $rd_trim_ct = 0;
    
    while (my $header = $input_fh->getline) {
        my $seq  = $input_fh->getline;
        my $sep  = $input_fh->getline;
        my $qual = $input_fh->getline;

        $ori_ct += (length $seq) - 1;#deduct new line 
        $rd_ori_ct++;
               
        chomp ($seq, $qual);
        my $seq_length = length $seq;

        my ($trim_seq, $trim_qual, $trimmed_length);
        my ($pos, $maxPos, $area, $maxArea) = ($seq_length, $seq_length, 0, 0);

        while ($pos > 0 and $area >= 0) {
		    $area += $self->trim_qual_level - (ord(substr($qual, $pos-1, 1)) - $qual_thresh);
		    if ($area > $maxArea) {
			    $maxArea = $area;
			    $maxPos = $pos;
		    }
		    $pos--;
        }
    
	    if ($pos == 0) { 
            ($trim_seq, $trim_qual) = ('N', $qual_str);# scanned whole read and didn't integrate to zero?  replace with "empty" read ...
        }
	    else {  # integrated to zero?  trim before position where area reached a maximum (~where string of qualities were still below 20 ...)
		    ($trim_seq, $trim_qual) = (substr($seq, 0, $maxPos),  substr($qual, 0, $maxPos));
        }
        $trimmed_length = $seq_length - $maxPos;
        
        my ($clean_header) = $header =~ /^@(\S+)\s+/;
	    $output_fh->print($header, $trim_seq."\n", $sep, $trim_qual."\n"); 

        if ($trimmed_length) {
            $trim_ct += $trimmed_length;
            $rd_trim_ct++;
            $report_fh->print($clean_header."\tT\t".$trimmed_length."\n"); #In report T for trimmed
        }
    }
    
    $input_fh->close;
    $output_fh->close; 

    my $new_ct  = $ori_ct - $trim_ct;
    my $percent = 100*$new_ct/$ori_ct;
        
    $report_fh->print("\nNumberOfOriginalBases  NumberOfTrimmedBases   NumberOfResultingBases  Percentage  NumberOfTrimmedReads\n");
    $report_fh->printf("%21s%22s%24s%11.1f%%%21s\n", $ori_ct, $trim_ct, $new_ct, $percent, $rd_trim_ct);
    $report_fh->close;
    
    return 1;
}

1;

