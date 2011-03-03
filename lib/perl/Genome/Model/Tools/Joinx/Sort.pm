package Genome::Model::Tools::Joinx::Sort;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Tools::Joinx::Sort {
    is => 'Genome::Model::Tools::Joinx',
    has_input => [
        input_files => {
            is => 'Text',
            is_many => 1,
            doc => 'List of bed files to sort',
            shell_args_position => 1,
        },
    ],
    has_optional_input => [
        merge_only => {
            is => 'Boolean',
            value => '0',
            doc => 'If set, then the pre-sorted input files just merged',
        },
        output_file => {
            is => 'Text',
            doc => 'The output file (defaults to stdout)',
        },
    ],
};

sub help_brief {
    "Sorts one or more bed files."
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
  gmt joinx sort a.bed [b.bed ...] --output-file sorted.bed
EOS
}

sub flags {
    my $self = shift;
    my @flags;
    push(@flags, "--merge-only") if $self->merge_only;
    return @flags;
}

sub execute {
    my $self = shift;
    my $output = "-";
    $output = $self->output_file if (defined $self->output_file);
    my @inputs = $self->input_files;
    my $flags = join(" ", $self->flags);
    my $cmd = $self->joinx_path . " sort $flags " .
        join(" ", @inputs) .
        " -o $output";


    my %params = (
        cmd => $cmd,
        # Sometimes these files come in empty in pipelines. We don't want this to choke when this happens, so don't check input file sizes.
        #input_files => \@inputs,
        allow_zero_size_output_files=>1,
    );
    $params{output_files} = [$output] if $output ne "-";
    Genome::Sys->shellcmd(%params);

    return 1;
}

1;
