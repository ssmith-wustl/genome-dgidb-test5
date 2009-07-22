package Genome::Model::Tools::Sam::SamToBam;

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Basename;


class Genome::Model::Tools::Sam::SamToBam {
    is  => 'Genome::Model::Tools::Sam',
    has => [ 
        sam_file    => { 
            is  => 'String',      
            doc => 'name of sam file',
        }
    ],
    has_optional => [
        bam_file    => {
            is  => 'String',
            doc => 'Name of output bam file (default: use base name of input sam file -- e.g. foo.sam -> foo.bam)'
        },
        ref_list    => {
            is  => 'String',
            doc => 'ref list contains ref name and its length, default is NCBI-human-build36/ref_list_for_bam',
            default => '/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/ref_list_for_bam',
        },
        index_bam   => {
            is  => 'Boolean',
            doc => 'flag to index bam file, default yes',
            default => 1,
        },
        fix_mate    => {
            is  => 'Boolean',
            doc => 'fix mate info problem in sam/bam, default yes',
            default => 1,
        },
        keep_sam    => {
            is  => 'Boolean',
            doc => 'flag to keep sam file, default no',
            default => 0,
        },
    ],
};


sub help_brief {
    'create bam file from sam file';
}


sub help_detail {
    return <<EOS 
This tool makes bam file from samfile with options to index bam file, fix mate pair info.
EOS
}


sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    $self->error_message('Sam file not existing') and return unless -e $self->sam_file;
    $self->error_message('Ref list not existing') and return unless -s $self->ref_list;
      
    return $self;
}


sub execute {
    my $self = shift;

    my $samtools = $self->samtools_path;
    my $sam_file = $self->sam_file;
    
    my ($root_name) = basename $sam_file =~ /^(\S+)\.sam/;
    
    my $sam_dir  = dirname $sam_file;
    my $bam_file = $self->bam_file || $sam_dir . "/$root_name.bam";
    
    my $cmd = sprintf('%s view -bt %s -o %s %s', $samtools, $self->ref_list, $bam_file, $sam_file);
    $self->status_message("SamToBam conversion command: $cmd");
    
    my $rv  = Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd, 
        output_files => [$bam_file],
        skip_if_output_is_present => 0,
    );
        
    $self->error_message("Converting to Bam command: $cmd failed") and return unless $rv == 1;
     
    #watch out disk space, for now hard code maxMemory 2000000000
    if ($self->fix_mate) {
        my $tmp_file = $bam_file.'.sort';
        $rv = system "$samtools sort -n -m 2000000000 $bam_file $tmp_file";
        $self->error_message("Sort by name failed") and return if $rv or !-s $tmp_file.'.bam';

        $rv = system "$samtools fixmate $tmp_file.bam $tmp_file.fixmate";
        $self->error_message("fixmate failed") and return if $rv or !-s $tmp_file.'.fixmate';
        unlink "$tmp_file.bam";

        $rv = system "$samtools sort -m 2000000000 $tmp_file.fixmate $tmp_file.fix";
        $self->error_message("Sort by position failed") and return if $rv or !-s $tmp_file.'.fix.bam';
        
        unlink "$tmp_file.fixmate";
        unlink $bam_file;

        move "$tmp_file.fix.bam", $bam_file;
    }

    if ($self->index_bam) {
        $rv = system "$samtools index $bam_file";
        $self->error_message('Indexing bam_file failed') and return if $rv;
    }

    unlink $sam_file unless $self->keep_sam;
    return 1;
}

1;
