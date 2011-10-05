package Genome::Model::Tools::DetectVariants2::Result::Combine::UnionSv;

use warnings;
use strict;

use Genome;
use File::Basename;

class Genome::Model::Tools::DetectVariants2::Result::Combine::UnionSv{
    is  => 'Genome::Model::Tools::DetectVariants2::Result::Combine',
    doc => 'Union svs into one file',
};

sub _needs_symlinks_followed_when_syncing { 0 };
sub _working_dir_prefix { 'union-sv' };
sub resolve_allocation_disk_group_name { 'info_genome_models' };
sub allocation_subdir_prefix { 'union_sv' };
sub _variant_type { 'svs' };

sub _combine_variants {
    my $self = shift;
    my $base_name = 'svs.hq';

    my ($dir_a, $dir_b) = ($self->input_directory_a, $self->input_directory_b);
    my @files = map{$_ .'/'. $base_name}($dir_a, $dir_b);
    my $output_file = $self->temp_staging_directory . '/' . $base_name;

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

    $self->status_message("Now make copy to sv merge outputs");
    
    for my $dir ($dir_a, $dir_b) {

        if ($dir =~ /union\-sv/) {
            $self->status_message("This is a union directory: $dir");
            $self->_copy_file($dir);
            next;
        }

        my $dir_type;

        if ($dir =~ /squaredancer/) {
            $dir_type = 'squaredancer.';
        }
        else { #for breakdancer output
            my $param_list = $self->_get_param_list($dir);
            next unless $param_list;
                        
            if ($param_list =~ /\-t/) {
                $dir_type = 'Inter.';
            }
            elsif ($param_list =~ /\-o/) {
                $dir_type = 'Intra.';
            }
            else {
                $self->warning_message("Failed to determine dir_type for params ($param_list).");
                next;
            }
        }
        $self->_copy_file($dir, $dir_type);
    }        
    return 1;
}


sub _get_param_list {
    my ($self, $dir) = @_;
    my $dir_target = readlink($dir);

    unless ($dir_target) {
        $self->warning_message("Failed to read the target from symlink ($dir).");
        return;
    }

    my $result_id = (split('-', $dir_target))[-1];
    unless ($result_id) {
        $self->warning_message("Failed to parse the result ID from target ($dir_target).");
        return;
    }

    my $result = Genome::Model::Tools::DetectVariants2::Result::Base->get($result_id);
    unless ($result) {
        $self->warning_message("Failed to get result for result ID ($result_id)");
        return;
    }
    my $param_list = $result->detector_params;
    return $param_list if $param_list;

    $self->warning_message("Failed to get detector_params for software_result: $result_id");
    return;
}


sub _copy_file {
    my ($self, $dir, $dir_type) = @_;
    my @file_names = map{$self->_variant_type.'.merge.'.$_}qw(fasta file file.annot out);

    for my $i (0..$#file_names) {
        my $file_type = $file_names[$i];
        if ($dir_type) {
            my $dest_name = $dir_type . $file_type;
            my $target = $dir .'/'. $file_type;
            my $dest   = $self->temp_staging_directory ."/$dest_name";
            unless (-e $target) {
                $self->warning_message("Target file: $target not existing");
                next;
            }
            unless (Genome::Sys->copy_file($target, $dest)) {
                $self->warning_message("Failed to copy $target to $dest");
            }
        }
        else { # for the case in sub union directory
            my @targets = glob($dir .'/*'. $file_type);
            unless (@targets) {
                $self->warning_message("$file_type can not be found in $dir");
                next;
            }
            unless (@targets == 2) {
                $self->warning_message("Expect 2 $file_type not ". scalar @targets);
            }
            for my $target (@targets) {
                my $dest_name = basename($target);
                my $dest      = $self->temp_staging_directory ."/$dest_name";
                unless (Genome::Sys->copy_file($target, $dest)) {
                    $self->warning_message("Failed to copy $target to $dest");
                }
            }
        }
    }
    return 1;
}


sub _validate_output {
    my $self = shift;
    my $variant_type = $self->_variant_type;
    my $out_file     = $self->temp_staging_directory.'/'.$variant_type.'.hq';

    for my $file ($out_file) {
        unless (-e $out_file) {
            die $self->error_message("Fail to find valid output file: $out_file");
        }
    }
    return 1;
}

1;
