package Genome::Model::Tools::Pindel::SortMate;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Pindel::SortMate {
    is => ['Command'],
    has => [
        unsorted_dumped_reads => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => '',
        },
        output_file => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => '',
        },
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
       ],
};

sub help_brief {
    "Fixes the sorting problem present in reads dumped from a bam where fixmate has not been run. This will sort all read pairs next to each other in output.";
}

sub help_synopsis {
    return <<"EOS"
gmt pindel sort-mate --unsorted-dumped-reads sample_reads --output-file sorted.out
gmt pindel sort-mate --unsorted sample_reads --output sorted.out
EOS
}

sub help_detail {                           
    return <<EOS 
    Fixes the sorting problem present in reads dumped from a bam where fixmate has not been run. This will sort all read pairs next to each other in output. Provide a file with dumped reads that need to be sorted by read pairs and obtain a list of paired reads contiguously in the output file
EOS
}

sub execute {
    my $self = shift;

    # Skip if both output files exist
    if (($self->skip_if_output_present)&&(-s $self->output_file)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    unless(-s $self->unsorted_dumped_reads) {
        $self->error_message("Input file zero size or not found.");
        return;
    }

    my $input_fh = IO::File->new($self->unsorted_dumped_reads);
    my $output_fh = IO::File->new($self->output_file, ">");

    unless($input_fh && $output_fh) {
        $self->error_message("Unable to open file handles for input and output");
        return;
    }

    my %read_hash;
    while (my $line = $input_fh->getline) {
        my ($read_name,) = split /\t/, $line;
        if (exists($read_hash{$read_name})) { 
            $output_fh->print($line);
            $output_fh->print($read_hash{$read_name});
            delete($read_hash{$read_name});
        }
        else {
            $read_hash{$read_name}=$line;
        }
    }

    $input_fh->close;
    $output_fh->close;

    return 1;
}

1;
