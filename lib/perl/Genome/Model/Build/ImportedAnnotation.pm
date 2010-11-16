package Genome::Model::Build::ImportedAnnotation;

use strict;
use warnings;
use Carp;

use Genome;
use Sys::Hostname;
use File::Find;
use File::stat;
use File::Spec;

class Genome::Model::Build::ImportedAnnotation {
    is => 'Genome::Model::Build',
    has => [
        version => { 
            via => 'inputs',
            is => 'Text',
            to => 'value_id', 
            where => [ name => 'version', value_class_name => 'UR::Value'], 
            is_mutable => 1 
        },
        annotation_data_source_directory => {
            via => 'inputs',
            is => 'Text',
            to => 'value_id',
            where => [ name => 'annotation_data_source_directory', value_class_name => 'UR::Value' ],
            is_mutable => 1 
        },
        species_name => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'species_name', value_class_name => 'UR::Value' ],
            is_mutable => 1,
        },
    ],
};

sub idstring {
    my $self = shift;
    return $self->model->name . "/" . $self->version;
}

# Checks to see if this build is compatible with the given imported reference sequence build (species and version match)
sub is_compatible_with_reference_sequence_build {
    # rsb: reference sequence build
    my ($self, $rsb) = @_;
    return if $self->status ne "Succeeded";
    my $version = $self->version;
    $version =~ s/^[^_]*_([0-9]+).*/$1/;
    return ($rsb->model->subject->species_name eq $self->model->subject->species_name) &&
        ($rsb->version eq $version);
}

# returns default location
sub determine_data_directory {
    my ($self) = @_;
    my @directories;
    my @composite_builds = $self->from_builds;
    if (@composite_builds) {
        for (@composite_builds) { 
            my @data_dirs = $_->determine_data_directory();
            return unless @data_dirs;
            push @directories, @data_dirs;
        }
    }
    else {
        if (-d $self->_annotation_data_directory) { 
            push @directories, $self->_annotation_data_directory;
        }
        else {
            $self->error_message("Could not find annotation data in " .
                $self->_annotation_data_directory);
            return;
        }
    }
    return @directories;
}

# Returns transcript iterator object using default location
sub transcript_iterator{
    my $self = shift;
    my %p = @_;

    my $chrom_name = $p{chrom_name};

    my @composite_builds = $self->from_builds;
    if (@composite_builds){
        my @iterators = map {$_->transcript_iterator(chrom_name => $chrom_name)} @composite_builds;
        my %cached_transcripts;
        for (my $i = 0; $i < @iterators; $i++) {
            my $next = $iterators[$i]->next;
            $cached_transcripts{$i} = $next if defined $next;
        }

        my $iterator = sub {
            my $index;
            my $lowest;
            for (my $i = 0; $i < @iterators; $i++) {
                next unless exists $cached_transcripts{$i} and $cached_transcripts{$i} ne '';
                unless ($lowest){
                    $lowest = $cached_transcripts{$i};
                    $index = $i;
                }
                if ($self->transcript_cmp($cached_transcripts{$i}, $lowest) < 0) {
                    $index = $i;
                    $lowest = $cached_transcripts{$index};
                }
            }
            unless (defined $index){
                #here we have exhausted both iterators
                return undef;
            }
            my $next_cache =  $iterators[$index]->next();
            $next_cache ||= '';
            $cached_transcripts{$index} = $next_cache;
            return $lowest;
        };

        bless $iterator, "Genome::Model::ImportedAnnotation::Iterator";
        return $iterator;
    }else{
        # Since this is not a composite build, don't have to worry about multiple results from determine data directory
        my ($data_dir) = $self->determine_data_directory();
        unless (defined $data_dir) {
            $self->error_message("Could not determine data directory for transcript iterator");
            return;
        }

        if ($chrom_name){
            return Genome::Transcript->create_iterator(where => [data_directory => $data_dir, chrom_name => $chrom_name]);
        }
        else {
            return Genome::Transcript->create_iterator(where => [data_directory => $data_dir]);
        }
    }
}

# Compare 2 transcripts by chromosome, start position, and transcript id
sub transcript_cmp {
    my $self = shift;
    my ($cached_transcript, $lowest) = @_;

    # Return the result of the chromosome comparison unless its a tie
    unless (($cached_transcript->chrom_name cmp $lowest->chrom_name) == 0) {
        return ($cached_transcript->chrom_name cmp $lowest->chrom_name);
    }

    # Return the result of the start position comparison unless its a tie
    unless (($cached_transcript->transcript_start <=> $lowest->transcript_start) == 0) {
        return ($cached_transcript->transcript_start <=> $lowest->transcript_start);
    }

    # Return the transcript id comparison result as a final tiebreaker
    return ($cached_transcript->transcript_id <=> $lowest->transcript_id);
}

# Location of annotation data in build directory
sub _annotation_data_directory{
    my $self = shift;
    return $self->data_directory . "/annotation_data";
}

sub annotation_file {
    my $self = shift;
    my $suffix = shift;
    unless ($suffix) {
        die('Must provide file suffix as parameter to annotation_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_annotation_data_directory .'/all_sequences.'. $suffix;
    if (-f $file_name) {
        return $file_name;
    }
    return;
}

sub rRNA_MT_file {
    my $self = shift;
    my $suffix = shift;
    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_MT_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_annotation_data_directory .'/rRNA_MT.'. $suffix;
    if (-f $file_name) {
        return $file_name;
    }
    return;
}

package Genome::Model::ImportedAnnotation::Iterator;
our @ISA = ('UR::Object::Iterator');

sub next {
    my $self = shift;
    return $self->();
}

1;
