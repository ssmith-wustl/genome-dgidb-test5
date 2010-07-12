package Genome::Model::Tools::Fastq::TrimBwaStyle2;

#Adapting from TrimBwaStyle.pl

use strict;
use warnings;

use Genome;
use File::Basename;


my $ori_ct     = 0;
my $trim_ct    = 0;
my $rd_ori_ct  = 0;
my $rd_trim_ct = 0;

my ($report, $report_fh);

class Genome::Model::Tools::Fastq::TrimBwaStyle2 {
    is  => 'Genome::Model::Tools::Fastq::Base',
    has_input => [
        trim_qual_level => {
            is  => 'Integer',
            doc => 'trim quality level',
            default => 10,
            is_optional => 1,
        },
        report_file => {
            is  => 'Text',
            doc => 'the file path of the trim report file, default is trim.report in the same dir as out_file',
            is_optional => 1,
        },
        trim_report => {
            is  => 'Boolean',
            doc => 'flag to output trim report or not',
            is_optional   => 1,
            default_value => 0,
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
        
    my $reader = $self->_open_reader
        or return;
    my $writer = $self->_open_writer
        or return;

    my @out_files = $self->output_files;
    my $out_dir   = dirname $out_files[0];
    #$self->out_file($out_file);

    if ($self->trim_report) {
        $report = $self->report_file || $out_dir . '/trim.report';
    
        if (-e $report) {
            $self->warning_message("Reprot file: $report existing. Overwrite it");
            unlink $report;
        }
        $report_fh = Genome::Utility::FileSystem->open_file_for_writing($report);
        unless ($report_fh) {
            $self->error_message("Failed to open report file " . $report . ": $!");
            return;
        }
    }
        
    while ( my $seqs = $reader->next ) {
        $self->trim($seqs);
        $writer->write($seqs);
    }

    my $new_ct  = $ori_ct - $trim_ct;
    my $percent = 100*$new_ct/$ori_ct;

    if ($self->trim_report) {
        $report_fh->print("\nNumberOfOriginalBases  NumberOfTrimmedBases   NumberOfResultingBases  Percentage  NumberOfTrimmedReads\n");
        $report_fh->printf("%21s%22s%24s%11.1f%%%21s\n", $ori_ct, $trim_ct, $new_ct, $percent, $rd_trim_ct);
        $report_fh->close;
    }

    return 1;
}


sub trim {
    my ($self, $seqs) = @_;
    
    my ($qual_str, $qual_thresh) = $self->type eq 'sanger' ? ('#', 33) : ('B', 64);
    
    for my $seq ( @$seqs ) {
        my $seq_length = length $seq->{seq};
        $ori_ct += $seq_length;
        $rd_ori_ct++;

        my ($trim_seq, $trim_qual, $trimmed_length);
        my ($pos, $maxPos, $area, $maxArea) = ($seq_length, $seq_length, 0, 0);

        while ($pos > 0 and $area >= 0) {
            $area += $self->trim_qual_level - (ord(substr($seq->{qual}, $pos-1, 1)) - $qual_thresh);
            if ($area > $maxArea) {
                $maxArea = $area;
                $maxPos  = $pos;
            }
            $pos--;
        }

        if ($pos == 0) { 
            # scanned whole read and didn't integrate to zero?  replace with "empty" read ...
            $seq->{seq}  = 'N';
            $seq->{qual} = $qual_str;
            #($trim_seq, $trim_qual) = ('N', $qual_str);# scanned whole read and didn't integrate to zero?  replace with "empty" read ...
        }
        else {  # integrated to zero?  trim before position where area reached a maximum (~where string of qualities were still below 20 ...)
            $seq->{seq}  = substr($seq->{seq},  0, $maxPos);
            $seq->{qual} = substr($seq->{qual}, 0, $maxPos);
        }
        $trimmed_length = $seq_length - $maxPos;

        if ($trimmed_length) {
            $trim_ct += $trimmed_length;
            $rd_trim_ct++;
            $report_fh->print($seq->{id}."\tT\t".$trimmed_length."\n") if $report_fh; #In report T for trimmed
        }
    }
    return $seqs;
}

1;

#$HeadURL$
#$Id$
