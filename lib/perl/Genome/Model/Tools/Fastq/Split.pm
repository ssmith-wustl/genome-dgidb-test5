package Genome::Model::Tools::Fastq::Split;

use strict;
use warnings;

use Genome;
use Cwd;
use File::Copy;

class Genome::Model::Tools::Fastq::Split {
    is  => 'Genome::Model::Tools::Fastq',
    has_input => [
        fastq_file => { is => 'Text' },
        sequences => {
            type => 'Integer',
            doc  => 'Number of fastq sequences for each output file',
        },
        output_directory => {
            is_optional => 1,
        }
    ],
    has_output => [
        fastq_files => { is_optional => 1, },
    ],
};

sub help_brief {
    'Divide fastq into chunk by chunk_size' 
}


sub help_detail {  
    return <<EOS
    Divide the fastq file of multi-fastq into chunk by given chunk_size. --show-list option will show the file path of chunk file list.
EOS
}


sub execute {
    my $self = shift;

    my @suffix = qw/\.txt \.fastq/;
    my ($fastq_basename,$fastq_dirname,$fastq_suffix) = File::Basename::fileparse($self->fastq_file,@suffix);
    unless ($fastq_basename && $fastq_dirname && $fastq_suffix) {
        die('Failed to parse fastq file name '. $self->fastq_file);
    }
    unless (Genome::Sys->validate_directory_for_read_write_access($fastq_dirname)) {
        $self->error_message('Failed to validate directory '. $fastq_dirname ." for read/write access:  $!");
        die($self->error_message);
    }

    my $cwd = getcwd;
    my $tmp_dir = $self->output_directory or Genome::Sys->base_temp_directory;
    chdir($tmp_dir);
    my $cmd = 'split -l '. $self->sequences * 4 .' -a 5 -d '. $self->fastq_file .' '. $fastq_basename.'-';
    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$self->fastq_file],
    );
    chdir($cwd);
    #If more than one lane processed in the same output_directory, this becomes a problem
    my @tmp_fastqs = grep { $_ !~ /\.$fastq_suffix$/ } grep { /$fastq_basename-\d+$/ } glob($tmp_dir .'/'. $fastq_basename.'*');
    my @fastq_files;

    # User should provide a directory as input, then we can keep output fastqs on tmp
    # and distribute bfqs in a downstream process
    # However, by default write fastqs to the source fastq file dir
    my $output_dir = $self->output_directory || $fastq_dirname;

    for my $tmp_fastq (@tmp_fastqs){
        my ($tmp_fastq_basename,$tmp_fastq_dirname) = File::Basename::fileparse($tmp_fastq);
        my $fastq_file = $output_dir .'/'. $tmp_fastq_basename . $fastq_suffix;
        unless (move($tmp_fastq,$fastq_file,) ) {
            die('Failed to move file '. $tmp_fastq .' to '. $fastq_file .":  $!");
        }
        push @fastq_files, $fastq_file;
    }
    
    $self->fastq_files(\@fastq_files);
    return 1;
}

1;

