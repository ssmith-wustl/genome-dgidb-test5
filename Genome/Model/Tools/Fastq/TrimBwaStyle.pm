package Genome::Model::Tools::Fastq::TrimBwaStyle;

#Adapting from TrimBwaStyle.pl

use strict;
use warnings;

use Genome;

use File::Basename;
require Genome::Model::Tools::Fastq::SetReader;
require Genome::Model::Tools::Fastq::SetWriter;

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
        
    my $reader = $self->_open_reader
        or return;
    my $writer = $self->_open_writer
        or return;

    my $out_file = $self->out_file;
    my $out_dir = dirname $out_file;
    $self->out_file($out_file);
    my $report = $self->report_file || $out_dir . '/trim.report';
    if (-e $report) {
        $self->warning_message("Reprot file: $report existing. Overwrite it");
        unlink $report;
    }
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

    while ( my $seqs = $reader->next ) {
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
                    $maxPos = $pos;
                }
                $pos--;
            }

            if ($pos == 0) { 
                # scanned whole read and didn't integrate to zero?  replace with "empty" read ...
                $seq->{seq} = 'N';
                $seq->{qual} = $qual_str;
                #($trim_seq, $trim_qual) = ('N', $qual_str);# scanned whole read and didn't integrate to zero?  replace with "empty" read ...
            }
            else {  # integrated to zero?  trim before position where area reached a maximum (~where string of qualities were still below 20 ...)
                $seq->{seq} = substr($seq->{seq}, 0, $maxPos);
                $seq->{qual} = substr($seq->{qual}, 0, $maxPos);
            }
            $trimmed_length = $seq_length - $maxPos;

            if ($trimmed_length) {
                $trim_ct += $trimmed_length;
                $rd_trim_ct++;
                $report_fh->print($seq->{id}."\tT\t".$trimmed_length."\n"); #In report T for trimmed
            }

        }
        $writer->write($seqs);
    }

    my $new_ct  = $ori_ct - $trim_ct;
    my $percent = 100*$new_ct/$ori_ct;

    $report_fh->print("\nNumberOfOriginalBases  NumberOfTrimmedBases   NumberOfResultingBases  Percentage  NumberOfTrimmedReads\n");
    $report_fh->printf("%21s%22s%24s%11.1f%%%21s\n", $ori_ct, $trim_ct, $new_ct, $percent, $rd_trim_ct);
    $report_fh->close;

    return 1;
}

sub _open_reader {
    my $self = shift;

    my $fastq_file = $self->fastq_file;
    my $reader;
    eval{
        $reader = Genome::Model::Tools::Fastq::SetReader->create(
            fastq_files => $fastq_file,
        );
    };
    unless ( $reader ) {
        $self->error_message("Can't create fastq reader for file ($fastq_file): $@");
        return;
    }

    return $reader;
}

sub _open_writer {
    my $self = shift;

    my $out_file = $self->out_file;
    unless ( $out_file ) {
        my ($base_name, $base_dir) = fileparse($self->fastq_file);
        $base_name =~ s/\.fastq$//;
        $out_file = $base_dir."/$base_name.trimmed.fastq";
        $self->out_file($out_file);
        if (-e $out_file) {
            $self->warning_message("Out file: $out_file existing. Overwrite it");
            unlink $out_file;
        }
    }

    my $writer;
    eval{
        $writer = Genome::Model::Tools::Fastq::SetWriter->create(
            fastq_files => $out_file,
        );
    };
    unless ( $writer ) {
        $self->error_message("Can't create fastq writer for file ($out_file): $@");
        return;
    }

    return $writer;
}

1;

#$HeadURL$
#$Id$
