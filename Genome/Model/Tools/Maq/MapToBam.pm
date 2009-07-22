package Genome::Model::Tools::Maq::MapToBam;

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Basename;

my $SAM_DEFAULT = Genome::Model::Tools::Sam->default_samtools_version;

class Genome::Model::Tools::Maq::MapToBam {
    is  => 'Genome::Model::Tools::Maq',
    has => [ 
        map_file    => { 
            is  => 'String',      
            doc => 'name of map file',
        }
    ],
    has_optional => [
        lib_tag     => {
            is  => 'String',
            doc => 'library name used in sam/bam file to identify read group',
            default => '',
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
        keep_sam    => {
            is  => 'Boolean',
            doc => 'flag to keep sam file, default no',
            default => 0,
        },
        fix_mate    => {
            is  => 'Boolean',
            doc => 'fix mate info problem in sam/bam, default yes',
            default => 1,
        },
        sam_version => {
            is  => 'String',
            doc => "samtools version to be used, default is $SAM_DEFAULT",
            default => $SAM_DEFAULT,
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

    my $samtools   = Genome::Model::Tools::Sam->path_for_samtools_version($self->sam_version);
    my $tool_path  = dirname $samtools;
    my $tosam_path = $tool_path.'/misc/maq2sam-';

    my ($ver) = $self->use_version =~ /^\D*\d\D*(\d)\D*\d/;
    $self->error_message("Give correct maq version") and return unless $ver;
    $tosam_path = $ver < 7 ? $tosam_path.'short' : $tosam_path.'long';

    my $map_file = $self->map_file;
    my $bam_file = $self->bam_file_path;
    my $sam_file = $bam_file;
    
    $sam_file =~ s/\.bam$/\.sam/;

    my $cmd = sprintf('%s %s %s > %s', $tosam_path, $map_file, $self->lib_tag, $sam_file);
    my $rv  = Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd, 
        output_files => [$sam_file],
        skip_if_output_is_present => 0,
        allow_zero_size_output_files => 1, #unit test would fail if not allowing empty output samfile.
    );

    $self->error_message("maq2sam command: $cmd failed") and return unless $rv == 1;

    my $sam2bam = Genome::Model::Tools::Sam::SamToBam->create(
        sam_file  => $sam_file,
        bam_file  => $bam_file,
        ref_list  => $self->ref_list,
        fix_mate  => $self->fix_mate,
        keep_sam  => $self->keep_sam,
        index_bam => $self->index_bam,
    );
    $rv = $sam2bam->execute;
    $self->error_message("SamToBam failed for $sam_file") and return unless $rv ==1;
  
    return 1;
}


sub bam_file_path {
    my $self     = shift;
    my $map_file = $self->map_file;

    my ($base, $dir) = fileparse($map_file);
    my ($root) = $base =~ /^(\S+)\.map/;

    return $dir.$root.'.bam';
}


1;
