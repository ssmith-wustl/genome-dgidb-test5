package Genome::Model::GenePrediction::Eukaryotic::ConvertRepeatMaskerAceFile;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Model::GenePrediction::Eukaryotic::ConvertRepeatMaskerAceFile {
    is => 'Command',
    has => [
        ace_file => {
            is => 'FilePath',
            is_input => 1,
            doc => 'Path to ace file produced by repeat masker',
        },
        gff_file => {
            is => 'FilePath',
            is_input => 1,
            doc => 'Path to gff file prodcued by repeat masker',
        },
        converted_ace_file => {
            is => 'FilePath',
            is_input => 1,
            is_output => 1,
            doc => 'Path to ace file produced by this tool that contains sequence names',
        },
    ],
};

sub help_brief {
    return 'Adds a sequence name to the repeat masker ace file';
}

sub help_synopsis {
    return help_brief();
}

sub help_detailed {
    return 'Takes an ace file produced by repeat masker and a gff file produced by repeat ' .
        'masker and produces a new ace file that includes sequence names';
}

sub execute {
    my $self = shift;

    $self->status_message("Converting ace file " . $self->ace_file . " to new ace format, " . 
        "output being placed in " . $self->converted_ace_file);

    my $ace_fh = $self->_get_ace_file_handle;
    Carp::confess 'Could not create file handle for input ace file ' . $self->ace_file unless $ace_fh;
    my $gff_fh = $self->_get_gff_file_handle;
    Carp::confess 'Could not create file handle for input gff file ' . $self->gff_file unless $gff_fh;
    my $output_fh = IO::File->new($self->converted_ace_file, 'w');
    Carp::confess 'Could not create file handle for output ace file ' . $self->converted_ace_file unless $output_fh;

    my $current_seq;
    my @lines_for_seq;
    my $line_count = 0;
    while (my $ace_line = $ace_fh->getline and my $gff_line = $gff_fh->getline) {
        chomp $ace_line;
        chomp $gff_line;

        $line_count++;
        if ($line_count % 1000 == 0) {
            $self->status_message("Converted $line_count lines of " . $self->ace_file);
        }

        my %ace_line_info = $self->_parse_ace_line($ace_line);
        my %gff_line_info = $self->_parse_gff_line($gff_line);

        unless ($self->_ace_line_matches_gff(\%ace_line_info, \%gff_line_info)) {
            $self->warning_message("Line $line_count from GFF file does not match line from ace file!");
            next;
        }

        if (not defined $current_seq or $current_seq eq $gff_line_info{'seq_name'}) {
            $current_seq = $gff_line_info{'seq_name'};
            my $converted_line = $self->_convert(\%ace_line_info, \%gff_line_info);
            push @lines_for_seq, $converted_line;
        }
        else {
            $output_fh->print("Sequence $current_seq\n");
            for my $line (@lines_for_seq) {
                $output_fh->print("$line\n");
            }
            $output_fh->print("\n");

            $current_seq = $gff_line_info{'seq_name'};
            @lines_for_seq = ($self->_convert(\%ace_line_info, \%gff_line_info));
        }
    }


    if (@lines_for_seq) {
        $output_fh->print("Sequence $current_seq\n");
        for my $line (@lines_for_seq) {
            $output_fh->print("$line\n");
        }
        $output_fh->print("\n");
    }

    $self->status_message("Done converting ace file!");
    $output_fh->close;
    $ace_fh->close;
    $gff_fh->close;
    return 1;
}

sub _convert {
    my ($self, $ace_line, $gff_line) = @_;
    my @line_columns;

    push @line_columns, $gff_line->{seq_name};
    push @line_columns,
        $ace_line->{repeat_name},
        $ace_line->{method},
        $ace_line->{percent_divergence},
        $ace_line->{start_in_query},
        $ace_line->{end_in_query},
        $ace_line->{start_in_consensus},
        $ace_line->{end_in_consensus};

    return join("\t", @line_columns);
}

sub _ace_line_matches_gff {
    my ($self, $ace_line, $gff_line) = @_;

    my @columns_to_check = qw/
        repeat_name
        percent_divergence
        start_in_query
        end_in_query
        start_in_consensus
        end_in_consensus
    /;

    for my $column (@columns_to_check) {
        my $ace = $ace_line->{$column};
        my $gff = $gff_line->{$column};

        return 0 unless defined $ace and defined $gff;
        return 0 unless $ace eq $gff;
    }

    return 1;
}

sub _get_ace_file_handle {
    my $self = shift;
    unless (-e $self->ace_file) {
        Carp::confess 'No file found at ' . $self->ace_file;
    }

    my $fh = IO::File->new($self->ace_file, 'r');
    unless ($fh) {
        Carp::confess 'Could not get file handle for ' . $self->ace_file;
    }

    return $fh;
}

sub _get_gff_file_handle {
    my $self = shift;
    unless (-e $self->gff_file) {
        Carp::confess 'No file found at ' . $self->gff_file;
    }

    my $fh = IO::File->new($self->gff_file, 'r');
    unless ($fh) {
        Carp::confess 'Could not get file handle for ' . $self->gff_file;
    }

    # Three lines of header to skip
    for (1..3) {
        $fh->getline;
    }

    return $fh;
}

sub _parse_ace_line {
    my ($self, $line) = @_;
    my @columns = $self->ace_columns;

    my @values = split(/\s+/, $line);
    shift @values; # first column is a constant value, don't care about it

    unless (@values == @columns) {
        Carp::confess "Line from ace file could not be parsed: $line";
    }

    my %line;
    for my $column_num (0..$#columns) {
        my $column = $columns[$column_num];
        my $value = $values[$column_num];
        $value =~ s/"//g;
        $line{$column} = $value;
    }

    return %line;
}

sub _parse_gff_line {
    my ($self, $line) = @_;
    my @columns = $self->gff_columns;

    my @values = split(/\s+/, $line);
    splice(@values, 1, 2); # Don't care about these values (RepeatMasker and Similarity)
    splice(@values, 5, 2); # Also don't care about these values (. and Target)

    unless (@values == @columns) {
        Carp::confess "Line from gff file could not be parsed: $line";
    }

    my %line;
    for my $column_num (0..$#columns) {
        my $column = $columns[$column_num];
        my $value = $values[$column_num];
        $value =~ s/"//g;

        if ($column eq 'repeat_name') {
            $value =~ s/Motif://g;
        }

        $line{$column} = $value;
    }

    return %line;
}

sub ace_columns {
    return qw/
        repeat_name
        method
        percent_divergence
        start_in_query
        end_in_query
        orientation
        end_in_consensus
        start_in_consensus
    /;
}

sub gff_columns {
    return qw/
        seq_name
        start_in_query
        end_in_query
        percent_divergence
        orientation
        repeat_name
        start_in_consensus
        end_in_consensus
    /;
}

1;

