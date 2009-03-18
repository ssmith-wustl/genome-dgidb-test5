package Genome::Model::Tools::Maq::MapToBam;

use strict;
use warnings;

use Genome;
use Command;
use File::Basename;
use File::Temp;
use IO::File;

class Genome::Model::Tools::Maq::MapToBam {
    is  => 'Command',
    has => [ 
        map_file    => { 
            is  => 'String',      
            doc => 'name of map file',
        }
    ],
    has_optional => [
        maq_version => {
            is  => 'String',
            doc => 'maq version used to make map file',
            default => '0.6.8',
        },
        lib_tag     => {
            is  => 'String',
            doc => 'library name used in sam/bam file to identify read group',
            default => '',
        },
        ref_list    => {
            is  => 'String',
            doc => 'ref list contains ref name and its length',
            default => '/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/ref_list_for_bam',
        },
        index_bam   => {
            is  => 'Boolean',
            doc => 'flag to index bam file',
            default => 1,
        },
        keep_sam    => {
            is  => 'Boolean',
            doc => 'flag to keep sam file',
            default => 0,
        },
    ],
};


sub help_brief {
    "create bam file from maq map file";
}


sub help_detail {
    return <<EOS 
This tool makes sam/bam file from maq map file with options to index bam file, keep sam file and use library tags. if maq version is below than 0.70, use maq2sam-short to convert, otherwise use maq2sam-long.
EOS
}


sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    $self->error_message('Map file not existing') and return unless -s $self->map_file;
    $self->error_message('Ref list not existing') and return unless -s $self->ref_list;
      
    return $self;
}


sub execute {
    my $self = shift;

    my $tool_path  = '/gscuser/dlarson/src/samtools/tags/samtools-0.1.2';
    my $tosam_path = $tool_path.'/misc/maq2sam-';
    my $samtools   = $tool_path.'/samtools';

    my ($ver) = $self->maq_version =~ /^\D*\d\D*(\d)\D*\d/;
    $self->error_message("Give correct maq version") and return unless $ver;
    $tosam_path = $ver < 7 ? $tosam_path.'short' : $tosam_path.'long';

    my $map_file = $self->map_file;
    my ($root_name) = basename $map_file =~ /^(\S+)\.map/;
    
    my $map_dir  = dirname $map_file;
    my $sam_file = $map_dir . "/$root_name.sam";
    my $bam_file = $map_dir . "/$root_name.bam";

    my $cmd = sprintf('%s %s %s > %s', $tosam_path, $map_file, $self->lib_tag, $sam_file);
    my $rv  = system $cmd;
    $self->error_message("$cmd failed") and return if $rv or !-s $sam_file;
    
    $cmd = sprintf('%s import %s %s %s', $samtools, $self->ref_list, $sam_file, $bam_file);
    $self->status_message("MapToBam conversion command: $cmd");
    $rv  = system $cmd;
    $self->error_message("$cmd failed") and return if $rv or !-s $bam_file;
     
    if ($self->index_bam) {
        $rv = system "$samtools index $bam_file";
        $self->error_message('Indexing bam_file failed') and return if $rv;
    }

    unlink $sam_file unless $self->keep_sam;
    return 1;
}

1;
