package Genome::Reference::Coverage::Bam;

use strict;
use warnings;

use Genome;

class Genome::Reference::Coverage::Bam {
    has => [
        bam_file => {
            is => 'String',
            doc => 'The BAM file to load',
        },
        bai_file => {
            is_calculated => 1,
            calculate_from => ['bam_file'],
            calculate => sub {
                my $bam_file = shift;
                return $bam_file .'.bai';
            },
        }
    ],
    has_optional => {
        bio_db_bam => { },
        bio_db_index => { },
        header => { },
    },
};


sub create {
    my $class = shift;
    my %params = @_;
    unless ($] > 5.012) {
        die "Bio::DB::Sam requires perl 5.12!";
    }
    require Bio::DB::Sam;
    my $self = $class->SUPER::create(@_);
    $self->_load;
    return $self;
}

sub _load {
    my $self = shift;
    my $bam  = Bio::DB::Bam->open( $self->bam_file );
    unless ($bam) {
        die('Failed to open BAM file '. $self->bam_file);
    }
    $self->bio_db_bam($bam);
    $self->header($bam->header);
    my $bai_file = $self->bai_file;
    my @symlinks;
    if (-e $bai_file) {
        while (-l $bai_file) {
            push @symlinks, $bai_file;
            $bai_file = readlink($bai_file);
        }
        my $bam_mtime = (stat($self->bam_file))[9];
        my $bai_mtime = (stat($bai_file))[9];
        if ($bam_mtime > $bai_mtime) {
            unless (unlink $bai_file) {
                die('Failed to remove old bai file'. $bai_file);
            }
        }
    }
    unless (-e $bai_file) {
        Bio::DB::Bam->index_build($self->bam_file);
        if (@symlinks) {
            @symlinks = reverse(@symlinks);
            my $to_file = $bai_file;
            for my $from_file (@symlinks) {
                unless (symlink($to_file,$from_file)) {
                    die('Failed to create symlink '. $from_file .' => '. $to_file);
                }
                $to_file = $from_file;
            }
        }
    }
    my $index  = Bio::DB::Bam->index_open( $self->bam_file );
    unless ($index) {
        die('Failed to find index for BAM file '. $self->bam_file);
    }
    $self->bio_db_index($index);
    return 1;
}


1;
