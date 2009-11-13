package Genome::Model::Tools::Fastq::Trimq2;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::Fastq::Trimq2 {
    is => 'Genome::Model::Tools::Fastq',
    has_optional => [
        out_file => {
            is  => 'Text',
            doc => 'the file name to use for the output file, default is xxx.trimq2.fastq',
        },
        report   => {
            is  => 'Boolean',
            doc => 'Generate trim report showing total number of original bases, trimmed bases, and resulting reduced bases, file name is xxx.trimq2.report',
            default => 1,
        },
        trimmed_original_fastq  => {
            is  => 'Boolean',
            doc => 'original fastq list of seq with q2 quality trimmed but will stay in out_file, file name is xxx.trimmed_original.fastq',
            default => 0,
        },
        length_limit => {
            is  => 'Integer',
            doc => 'length limit of first Q2 position to 5 prime end (left), the reads fastq failing this limit will be thrown into xxxx.trimq2.filtered.fastq',
            default => 32,
        },
        output_dir => {
            is  => 'Text',
            doc => 'The directory that report, filtered.fastq, trimmed_original_fastq will be written to, default is the same path as fastq_file',
        },
    ],
};

sub help_synopsis {
    return <<EOS
gt fastq trimq2 --fastq-file=lane1.fastq --out-file=lane1.trimmed.fastq

EOS
}

sub help_detail {
    return <<EOS 
Trims fastq reads with phred quality 2 as either Illumina quality string as B (quality value 66) or sanger quality string as # (quality value 35)
EOS
}


sub execute {
    my $self = shift;

    my $out_dir;
    if ($self->output_dir) {
        unless (-d $self->output_dir) {
            $self->error_message('output dir provided does not exist: '.$self->output_dir);
            return;
        }
        $out_dir = $self->output_dir;
    }
    
    my $fastq_file = $self->fastq_file;
    my ($base_name, $base_dir) = fileparse($fastq_file);
    $base_name =~ s/\.fastq$// if $base_name =~ /\.fastq$/;

    $out_dir ||= $base_dir;
    
    my $filter_file= $out_dir . "/$base_name.trimq2.filtered.fastq";
    my $out_file   = $self->out_file || $fastq_file . '.trimq2.fastq';
    
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

    my $filter_fh = Genome::Utility::FileSystem->open_file_for_writing($filter_file);
    unless ($filter_fh) {
        $self->error_message('Failed to open filtered file '. $filter_file . ": $!");
        return;
    }
    binmode $filter_fh, ":utf8";

    my $report_fh;
    if ($self->report) {
        my $report = $out_dir . "/$base_name.trimq2.report";
        $report_fh = Genome::Utility::FileSystem->open_file_for_writing($report);
        unless ($report_fh) {
            $self->error_message("Failed to open report file " . $report . ": $!");
            return;
        }
        binmode $report_fh, ":utf8";
    }

    my $ori_fq_fh;
    if ($self->trimmed_original_fastq) {
        my $ori_fq = $out_dir . "/$base_name.trimmed_original.fastq";
        $ori_fq_fh = Genome::Utility::FileSystem->open_file_for_writing($ori_fq);
        unless ($ori_fq_fh) {
            $self->error_message("Failed to open report file " . $ori_fq . ": $!");
            return;
        }
        binmode $ori_fq_fh, ":utf8";
    }

    my $ori_ct    = 0;
    my $trim_ct   = 0;
    my $filter_ct = 0;

    my $rd_ori_ct    = 0;
    my $rd_trim_ct   = 0;
    my $rd_filter_ct = 0; 
    
    my $qual_str = $self->solexa_fastq ? 'B' : '#';
    
    while (my $header = $input_fh->getline) {
        my $seq  = $input_fh->getline;
        my $sep  = $input_fh->getline;
        my $qual = $input_fh->getline;
        
        my ($clean_header) = $header =~ /^@(\S+)\s+/;
        
        my $seq_length = (length $seq) - 1; #account for new line
        $ori_ct += $seq_length; 
        $rd_ori_ct++;
        
        if ($qual =~ /$qual_str/) {
            my ($trim_qual) = $qual =~ /^(\S*?)$qual_str/;
            my $trim_length = length $trim_qual;
            
            if ($trim_length >= $self->length_limit ) {
                my $trimmed_length = $seq_length - $trim_length;
                $output_fh->print($header, substr($seq, 0, $trim_length)."\n", $sep, $trim_qual."\n"); 
                $ori_fq_fh->print($header, $seq, $sep, $qual) if $ori_fq_fh;
                $report_fh->print($clean_header."\tT\t".$trimmed_length."\n") if $report_fh;  #In report T for trimmed
                $trim_ct += $trimmed_length;
                $rd_trim_ct++;
            }
            else {
                $filter_fh->print($header, $seq, $sep, $qual);
                $report_fh->print($clean_header."\tF\t".$seq_length."\n") if $report_fh;  #In report F for filtered
                $filter_ct += $seq_length;
                $rd_filter_ct++;
            }
        }
        else {
            $output_fh->print($header, $seq, $sep, $qual);
        }
    }
    
    $input_fh->close;
    $output_fh->close; 
    $filter_fh->close;
    $ori_fq_fh->close if $ori_fq_fh;

    if ($self->report) {
        my $rd_new_ct  = $rd_ori_ct - $rd_filter_ct;
        my $rd_percent = 100*$rd_new_ct/$rd_ori_ct;
        my $new_ct  = $ori_ct - $trim_ct - $filter_ct;
        my $percent = 100*$new_ct/$ori_ct;
        
        $report_fh->print("\nNumberOfOriginalReads  NumberOfTrimmedReads  NumberOfFilteredReads  NumberOfRemainingReads  Percentage\n");
        $report_fh->printf("%21s%22s%23s%24s%11.1f%%\n", $rd_ori_ct, $rd_trim_ct, $rd_filter_ct, $rd_new_ct, $rd_percent);
        $report_fh->print("\nNumberOfOriginalBases  NumberOfTrimmedBases  NumberOfFilteredBases  NumberOfResultingBases  Percentage\n");
        $report_fh->printf("%21s%22s%23s%24s%11.1f%%\n", $ori_ct, $trim_ct, $filter_ct, $new_ct, $percent);
        $report_fh->close;
    }
    
    return 1;
}

1;

