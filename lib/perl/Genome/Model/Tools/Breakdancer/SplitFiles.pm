package Genome::Model::Tools::Breakdancer::SplitFiles;

use strict;
use warnings;
use Genome;
use File::Basename 'dirname';
use Carp 'confess';

class Genome::Model::Tools::Breakdancer::SplitFiles {
    is => 'Command',
    has => [
        input_file => {
            is => 'FilePath',
            doc => 'Breakdancer file to be split up',
        },
    ],
    has_optional => [
        output_directory => {
            is => 'DirectoryPath',
            doc => 'Directory into which split files should go, defaults to same directory as input file',
        },
        output_file_template => {
            is => 'String',
            doc => 'Naming scheme that output file should follow, CHR is replaced with chromosome name',
            default => 'breakdancer_CHR',
        },
        output_files => {
            is => 'ARRAY',
            is_transient => 1,
            doc => 'Array containing paths of all created output files',
        },
    ],
};

sub help_synopsis {
    return 'Splits up a breakdancer output file by chromosome';
}

sub help_brief {
    return 'Splits up a breakdancer output file by chromosome';
}

sub help_detail {
    return 'Splits up a breakdancer output file by chromosome';
}

sub headers {
    return qw/ 
        chr1
        pos1
        orientation1
        chr2
        pos2
        orientation2
        type
        size
        score
        num_reads
        num_reads_lib
        allele_frequency
    /;
}

# Unfortunately, separated value reader has no method that returns the original line, so you
# have to use the hash and headers to remake it. Lame.
sub recreate_original_line {
    my ($self, $line_hash) = @_;
    return join("\t", map { $line_hash->{$_ } } $self->headers);
}

sub execute {
    my $self = shift;
    confess 'No file at ' . $self->input_file unless -e $self->input_file;

    if (defined $self->output_directory) {
        my $dir = Genome::Sys->create_directory($self->output_directory);
        confess 'Could not find or create output directory ' . $self->output_directory unless defined $dir;
    }
    else {
        my $dir = dirname($self->input_file);
        confess "Could not create output directory $dir!" unless Genome::Sys->create_directory($dir);
        $self->output_directory($dir);
    }

    unless ($self->output_file_template =~ /CHR/) {
        $self->warning_message("Given template without CHR, appending it to the end");
        $self->output_file_template($self->output_file_template . 'CHR');
    }

    $self->status_message("Split files being written to " . $self->output_directory);

    my $input_fh = IO::File->new($self->input_file, 'r');
    my %output_handles;
    my $output_fh;
    my $chrom;
    my $svr = Genome::Utility::IO::SeparatedValueReader->create(
        headers => [$self->headers],
        input => $self->input_file,
        separator => "\t",
        is_regex => 1,
        ignore_extra_columns => 1,
    );
    confess 'Could not create reader for input file ' . $self->input_file unless $svr;
    
    $DB::single = 1;
    my $line = $svr->next;
    my $header = $self->recreate_original_line($line);

    my @files;
    while ($line = $svr->next) {
        unless (defined $chrom and $chrom eq $line->{chr1}) {
            $chrom = $line->{chr1};
            if (exists $output_handles{$chrom}) {
                $output_fh = $output_handles{$chrom};
            }
            else {
                my $file_name = $self->output_directory . '/' . $self->output_file_template;
                $file_name =~ s/CHR/$chrom/;
                unlink $file_name if -e $file_name;
                $output_fh = IO::File->new($file_name, 'w');
                confess "Could not get file handled for output file $output_fh!" unless $output_fh;
                $output_handles{$chrom} = $output_fh;
                $output_fh->print($header . "\n");
                push @files, $file_name;
                $self->status_message("Created output file $file_name");
            }
        }

        $output_fh->print($self->recreate_original_line($line) . "\n");
    }

    $input_fh->close;
    map { $output_handles{$_}->close } keys %output_handles;
    $self->output_files(\@files);
    return 1;
}

1;

