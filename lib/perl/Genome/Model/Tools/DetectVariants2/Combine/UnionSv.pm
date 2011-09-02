package Genome::Model::Tools::DetectVariants2::Combine::UnionSv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::UnionSv{
    is  => 'Genome::Model::Tools::DetectVariants2::Combine',
    doc => 'Union svs into one file',
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'svs',
            doc => 'variant type that this module operates on',
        },
    ],
};

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file
EOS
}


sub _combine_variants {
    my $self = shift;
    my $base_name = 'svs.hq';

    my ($dir_a, $dir_b) = ($self->input_directory_a, $self->input_directory_b);
    my @files = map{$_ .'/'. $base_name}($dir_a, $dir_b);
    my $output_file = $self->output_directory . '/' . $base_name;

    if (-z $files[0] and -z $files[1]) {
        $self->warning_message("0 size of $base_name from both input dir. Probably for testing of small bams");
        `touch $output_file`;
    }
    else {
        my $input_files = join ',', @files;
        my $union_command = Genome::Model::Tools::Breakdancer::MergeFiles->create(
            input_files => $input_files,
            output_file => $output_file,
        );

        unless ($union_command->execute) {
            $self->error_message("Error executing union command");
            die $self->error_message;
        }
    }

    $self->status_message("Now make symlink to sv merge outputs");
    my @file_names = map{$self->_variant_type.'.merge.'.$_}qw(fasta file file.annot out);

    DIR: for my $dir ($dir_a, $dir_b) {
        my $dir_target = readlink($dir);
        unless ($dir_target) {
            $self->warning_message("Failed to read the target from symlink ($dir).");
            next DIR;
        }

        my $result_id = (split('-', $dir_target))[-1];
        unless ($result_id) {
            $self->warning_message("Failed to parse the result ID from target ($dir_target).");
            next DIR;
        }

        my $result = Genome::Model::Tools::DetectVariants2::Result::Base->get($result_id);
        unless ($result) {
            $self->warning_message("Failed to get result for result ID ($result_id)");
            next DIR;
        }

        my $param_list = $result->detector_params;
        my $dir_type;
        if ($param_list =~ /\-q 10 \-d/) {
            $dir_type = 'Inter.';
        }
        elsif ($param_list =~ /\-q 10 \-o/) {
            $dir_type = 'Intra.';
        }
        else {
            $self->warning_message("Failed to determine dir_type for params ($param_list).");
            next DIR;
        }
        COPY: for my $i (0..$#file_names) {
            my $target = $dir .'/'. $file_names[$i];
            my $dest   = $self->output_directory ."/$dir_type". $file_names[$i];

            if (-e $target) {
                #unless (Genome::Sys->create_symlink($target, $link)) {
                unless (Genome::Sys->copy_file($target, $dest)) {
                    $self->warning_message("Failed to copy $target to $dest");
                    next COPY;
                }
            }
            else {
                $self->warning_message("Target file: $target not existing");
            }
        }
    }
    return 1;
}


sub _validate_output {
    my $self = shift;
    my $variant_type = $self->_variant_type;
    my $out_file     = $self->output_directory.'/'.$variant_type.'.hq';

    for my $file ($out_file) {
        unless (-e $out_file) {
            die $self->error_message("Fail to find valid output file: $out_file");
        }
    }
    return 1;
}

1;
