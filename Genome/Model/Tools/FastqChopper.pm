package Genome::Model::Tools::FastqChopper;

use strict;
use warnings;

use above "Genome";
use Command;
use File::Temp;
use IO::File;

class Genome::Model::Tools::FastqChopper {
    is => 'Command',
    has => [ 
            'fastq_file'   => { is => 'String',    doc => "fastq file"},
            'size'         => { is => 'Integer',   doc => "The size, number of sequences, to split files into",
                                is_optional => 1},
            'sub_fastq_files' => {is => 'list', doc => "A list of fastq files of which the original fastq was broken into",
                              is_optional => 1},
    ],
};

sub help_brief {
    "splits a fastq file into multiple smaller files of set size";
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
This takes a fastq file and splits it into smaller files and returns the paths to those files
EOS
}

sub create {
    my $class = shift;
    $DB::single = $DB::stopper;
    my $self = $class->SUPER::create(@_);
    unless (defined($self->size)){
        $self->size(250000);
    }
    return $self;
}

sub execute {
    my $self = shift;

    my $fastq_fh = IO::File->new($self->fastq_file);
    unless ($fastq_fh) {
        die("can't open " ,  $self->fastq_file , ": $!");
    }
    my @output_file_list;
    my @lines = $fastq_fh->getlines;
    while (@lines) {
        my @sub_lines = splice(@lines,0,$self->size * 4);
        my ($out_fh,$output_file) = File::Temp::tempfile;
        unless ($out_fh) {
            $self->error_message("Failed to open file $output_file for output:  $!");
            return;
        }
        for my $line (@sub_lines) {
            $out_fh->print($line);
        }
        push(@output_file_list, $output_file);
        $out_fh->close;
    }
    $self->sub_fastq_files(\@output_file_list);
    return 1;
}

sub DESTROY {
    my $self = shift;
    my $ref = $self->sub_fastq_files;
    for my $file (@$ref) {
        unlink $file;
    }
}

1;
