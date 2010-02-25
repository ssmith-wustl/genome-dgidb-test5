package Genome::Model::Tools::Fastq::Trimq2::Simple;

#This module will keep trimmed pair_end as "it is", not mess up with
#pair and pair_as_fragment. This module will trim fastq with two ways:
#1. Hard trim: trim all bases from the first phred qual 2 base to 3'end
#2. Bwa trim: trim using BWA style like what is used in 'bwa aln -q '.
#
#Hard style will leave trimmed seq as "it is", while Bwa style will
#probably trim off some non-phredqual2 seqs.
#
#For now both trim is only applied to sequences containing phred
#quality 2 string. Bwa trim style can be used for all sequences.

#For bwa trim style, bwa_trim_qual_level 10 is reasonable, while 20
#overtrims a lot. bwa trim with 10 is also tolerable to single Q2 base
#in the middle, and usually "shrink" the short trimmed seqs into 1
#base/qual as "N/#" to avoid too short seqs passed into aligner

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::Fastq::Trimq2::Simple {
    is  => 'Genome::Model::Tools::Fastq::Trimq2',
    has => [
        fastq_file  => {
            is  => 'Text',
            doc => 'the fastq file name to use for trim',
        }, 
        out_file    => {
            is  => 'Text',
            doc => 'the file name to use for the output file, default is xxx.trimq2.fastq in fastq_file dir',
            is_optional => 1,
        },
        trim_style => {
            is  => 'Text',
            doc => 'Trim style to use: hard or soft, the choices are [hard], bwa',
            default => 'hard',
            is_optional => 1,
        },
        bwa_trim_qual_level => {
            is  => 'Integer',
            doc => 'quality level of bwa trim style, default is 10',
            default => 10,
            is_optional => 1,
        },
    ],
};

sub help_synopsis {
    return <<EOS
gmt fastq trimq2 simple --fastq-file=lane1.fastq --out-file=lane1.trimmed.fastq
EOS
}

sub help_detail {
    return <<EOS 
Trims fastq reads with phred quality 2 as either Illumina quality string as B (quality value 66) or sanger quality string as # (quality value 35)
EOS
}


sub execute {
    my $self    = shift;
    my $out_dir = $self->output_dir;
        
    my $fastq_file = $self->fastq_file;
    unless (-s $fastq_file) {
        $self->error_message("Fastq file : $fastq_file not existing");
        return;
    }
    
    my ($base_name, $base_dir) = fileparse($fastq_file);
    $base_name =~ s/\.fastq$// if $base_name =~ /\.fastq$/;

    $out_dir ||= $base_dir;
    my $out_file = $self->out_file || $out_dir."/$base_name.trimq2.fastq";
    my $report   = $self->report_file || $out_dir . "/trimq2.report";

    $self->out_file($out_file);
    
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

    my $ori_ct     = 0;
    my $trim_ct    = 0;
    my $rd_ori_ct  = 0;
    my $rd_trim_ct = 0;
    
    my $qual_str = $self->trim_string;
    
    while (my $header = $input_fh->getline) {
        my $seq  = $input_fh->getline;
        my $sep  = $input_fh->getline;
        my $qual = $input_fh->getline;
        
        $ori_ct += (length $seq) - 1;#deduct new line 
        $rd_ori_ct++;
                
        if ($qual =~ /$qual_str/) {
            chomp ($seq, $qual);
            my $seq_length = length $seq;

            my $trim_style = $self->trim_style;
            my ($trim_seq, $trim_qual, $trimmed_length);

            if ($trim_style =~ /^hard$/i) {
                ($trim_qual) = $qual =~ /^(\S*?)$qual_str/;
                my $trim_length = length $trim_qual;            
                $trimmed_length = $seq_length - $trim_length;
                
                $trim_seq  = $trim_qual ? substr($seq, 0, $trim_length) : 'N';
                $trim_qual ||= $qual_str;
                
            }
            elsif ($trim_style =~ /^bwa$/i) {#This style look for continuous low qual on 3' end
                my ($pos, $maxPos, $area, $maxArea) = ($seq_length, $seq_length, 0, 0);

                while ($pos > 0 and $area >= 0) {#If last base qual is high, loop will be ended even though it could contain Q2 base in the middle. In this case, nothing trimmed.
		            $area += $self->bwa_trim_qual_level - (ord(substr($qual, $pos-1, 1)) - 33);
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
                    $maxPos-- if $qual =~ /$qual_str$/;  #if last base is qual_str, need trim it. qual_str is observed left untrimmed when bwa_trim_qual_level is 10
		            ($trim_seq, $trim_qual) = (substr($seq, 0, $maxPos),  substr($qual, 0, $maxPos));
		        }
                $trimmed_length = $seq_length - $maxPos;
            }
            else {
                $self->error_message("Invalid trim style: $trim_style");
                return;
            }
            
            my ($clean_header) = $header =~ /^@(\S+)\s+/;

	        $output_fh->print($header, $trim_seq."\n", $sep, $trim_qual."\n"); 
            $report_fh->print($clean_header."\tT\t".$trimmed_length."\n");  #In report T for trimmed
            $trim_ct += $trimmed_length;
            $rd_trim_ct++;

        }
        else {
            $output_fh->print($header, $seq, $sep, $qual);
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

