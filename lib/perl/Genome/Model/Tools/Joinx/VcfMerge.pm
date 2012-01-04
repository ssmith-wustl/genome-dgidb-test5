package Genome::Model::Tools::Joinx::VcfMerge;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Tools::Joinx::VcfMerge {
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
        clear_filters => {
            is => 'Boolean',
            default => 0,
            doc => 'Merged entries will have the FILTER column stripped out (-c option)',
        },
        merge_samples => {
            is => 'Boolean',
            default => 0,
            doc => 'Allow input files with overlapping samples (-s option)',
        },
        output_file => {
            is => 'Text',
            is_output => 1,
            doc => 'The output file (defaults to stdout)',
        },
        use_bgzip => {
            is => 'Boolean',
            doc => 'zcats the input files into stdin, and bgzips the output',
            default => 0,
        },
        joinx_bin_path => {
            is => 'Text',
            doc => 'path to the joinx binary to use. This tool is being released before joinx vcf-merge will be released. This will go away when it is.',
        },
        error_log => {
            is => 'Text',
            doc => 'path to the error log file, if desired',
        },
    ],
};

sub help_brief {
    "Sorts one or more bed files."
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
  gmt joinx vcf-merge a.vcf b.vcf ... --output-file merged.vcf
EOS
}

sub execute {
    my $self = shift;
    if(defined($self->use_bgzip) && not defined($self->output_file)){
       die $self->error_message("If use_bgzip is set, output_file must also be set, otherwise binary nonsense will spew forth."); 
    }
    my $output = "-";
    $output = $self->output_file if (defined $self->output_file);
    # Grep out empty files
    my @inputs = grep { -s $_ } $self->input_files;

    # If all input files are empty, make sure the output file at least exists
    unless (@inputs) {
        if (defined $self->output_file) {
            unless (system("touch $output") == 0) {
                die $self->error_message("Failed to touch $output");
            }
        }
        return 1;
    }
    
    if($self->use_bgzip){
        my @new_inputs;
        for my $input (@inputs){
            push @new_inputs, "<(zcat $input)";
        }
        @inputs = @new_inputs;
    }

    unless($self->joinx_bin_path){
        $self->joinx_bin_path($self->joinx_path);
    }
    my $flags = "";
    if ($self->clear_filters) {
        $flags .= " -c";
    }
    if ($self->merge_samples) {
        $flags .= " -s";
    }
    my $cmd = $self->joinx_bin_path . " vcf-merge $flags " . join(" ", @inputs);
    if(defined($self->output_file) && not defined($self->use_bgzip)){
        if (defined $self->error_log) {
            $cmd .= " -o $output 2> " . $self->error_log;
        } else {
            $cmd .= " -o $output";
        }
    } elsif ( defined($self->use_bgzip) && defined($self->output_file) ){
        if (defined $self->error_log) {
            $cmd .= " 2> " . $self->error_log . " | bgzip -c > $output";
        } else {
            $cmd .= " | bgzip -c > $output";
        }
        $cmd = "bash -c \'$cmd\'";
    }

    my %params = (
        cmd => $cmd,
        allow_zero_size_output_files=>1,
    );
    $params{output_files} = [$output] if $output ne "-";
    Genome::Sys->shellcmd(%params);

    return 1;
}

1;
