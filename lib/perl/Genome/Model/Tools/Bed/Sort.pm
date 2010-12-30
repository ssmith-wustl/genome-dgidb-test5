package Genome::Model::Tools::Bed::Sort;

use strict;
use warnings;

use Sort::Naturally;
use Genome;

class Genome::Model::Tools::Bed::Sort {
    is => ['Command'],
    doc => 'Sort a BED file in memory and write it to a new file',
    has_input => [
        input => {
            is => 'File',
            shell_args_position => 1,
            doc => 'The input BED file to be sorted',
        },
        output => {
            is => 'File',
            shell_args_position => 2,
            doc => 'Where to write the output BED file',
        },
    ],
    has_transient_optional => [
        _input_fh => {
            is => 'IO::File',
            doc => 'Filehandle for the source BED file',
        },
        _output_fh => {
            is => 'IO::File',
            doc => 'Filehandle for the output BED file',
        },
    ]
};

sub help_brief {
    "Sort BED files.";
}

sub help_synopsis {
    "gmt bed sort a.bed b.bed";
}

sub help_detail {
    "Sort a BED file in memory and write it to a new file";
}

sub execute {
    my $self = shift;

    return unless($self->initialize_filehandles);
    my $retval = $self->sort;
    $self->close_filehandles;
    return $retval;
}

sub initialize_filehandles {
    my $self = shift;

    if($self->_input_fh || $self->_output_fh) {
        return 1; #Already initialized
    }

    my $input = $self->input;
    my $output = $self->output;

    eval {
        my $input_fh = Genome::Utility::FileSystem->open_file_for_reading($input);
        my $output_fh = Genome::Utility::FileSystem->open_file_for_writing($output);

        $self->_input_fh($input_fh);
        $self->_output_fh($output_fh);
    };

    if($@) {
        $self->error_message('Failed to open file. ' . $@);
        $self->close_filehandles;
        return;
    }

    return 1;
}

sub close_filehandles {
    my $self = shift;

    my $input_fh = $self->_input_fh;
    close($input_fh) if $input_fh;

    my $output_fh = $self->_output_fh;
    close($output_fh) if $output_fh;

    return 1;
}

sub sort  {
    my $self = shift;
    my @lines;
    my $in = $self->_input_fh;
    my $line_num = 0;
    while (<$in>) {
        ++$line_num;
        chomp;
        my $l = [split("\t")];
        die "Invalid BED line at line #$line_num: '$_'" if @$l < 3;
        push @lines, $l;
    }

    @lines = sort {
        ncmp($a->[0], $b->[0]) || $a->[1] <=> $b->[1] || $a->[2] <=> $b->[2]
    } @lines;

    for my $l (@lines) {
        $self->_output_fh->print(join("\t", @$l)."\n");
    }
    return 1;
}

1;
