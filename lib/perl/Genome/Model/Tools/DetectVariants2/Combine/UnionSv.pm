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
    my ($dir_a, $dir_b) = ($self->input_directory_a, $self->input_directory_b);

    for my $file_name qw(svs.hq) {
        my @files = map{$_.'/'.$file_name}($dir_a, $dir_b);
        my $input_files = join ',', @files;
        my $output_file = $self->output_directory.'/'.$file_name;

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
        my $dir_type;
        if ($dir =~ /\-q_10_\-d/) {
            $dir_type = 'Inter.';
        }
        elsif ($dir =~ /\-q_10_\-o/) {
            $dir_type = 'Intra.';
        }
        else {
            $self->warning_message("Failed to figure out the dir type for $dir");
            next DIR;
        }
        LINK: for my $i (0..$#file_names) {
            my $target = $dir .'/'. $file_names[$i];
            my $link   = $self->output_directory ."/$dir_type". $file_names[$i];
            
            if (-e $target) {
                unless (Genome::Sys->create_symlink($target, $link)) {
                    $self->warning_message("Failed to symlink $target to $link");
                    next LINK;
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
