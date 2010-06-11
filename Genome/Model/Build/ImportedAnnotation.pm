package Genome::Model::Build::ImportedAnnotation;

use strict;
use warnings;

use Genome;

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

# Checks if data is cached. Returns the cache location if found, otherwise returns default location
sub determine_data_directory {
    my $self = shift;
    my @directories;
    my @composite_builds = $self->from_builds;
    if (@composite_builds) {
        for (@composite_builds) { 
            my @data_dirs = $_->determine_data_directory;
            return unless @data_dirs;
            push @directories, @data_dirs;
        }
    }
    else {
        if (-d $self->_cache_directory) {
            push @directories, $self->_cache_directory; 
        }
        elsif (-d $self->_annotation_data_directory) { 
            push @directories, $self->_annotation_data_directory;
        }
        else {
            $self->error_message("Could not find annotation data in " . $self->_cache_directory .
                " or " . $self->_annotation_data_directory);
            return;
        }
    }
    return @directories;
}

# Caches annotation data in a temporary directory, then moves it to the final location
# Returns annotation data directory that should be used
sub cache_annotation_data {
    my $self = shift;

    my @composite_builds = $self->from_builds;
    if (@composite_builds) {
        for (@composite_builds) { $_->cache_annotation_data }
    }
    else {
        if (-d $self->_cache_copying_directory) {
            $self->status_message("Caching in progress (" . $self->_cache_copying_directory.
                "), using annotation data dir at " . $self->_annotation_data_directory);
            return $self->_annotation_data_directory;
        }
        elsif (-d $self->_cache_directory) {
            $self->status_message("Updating local annotation data cache");
            $self->_update_cache;
            $self->status_message("Cache successfully updated"); 
            return $self->_cache_directory;
        }
        else {
            $self->status_message("No local cache found at " . $self->_cache_directory .
                ", copying files from " . $self->_annotation_data_directory);
            my $mkdir_rv = Genome::Utility::FileSystem->shellcmd(cmd => "mkdir -p " . $self->_cache_copying_directory);
            unless ($mkdir_rv) {
                $self->error_message("Error encountered while making directory at " . $self->_cache_copying_directory);
                die;
            }

            my $cp_rv = Genome::Utility::FileSystem->shellcmd(
                cmd => "cp -Lr " . $self->_annotation_data_directory . "/* " . $self->_cache_copying_directory
            );
            unless ($cp_rv) {
                $self->error_message("Error encountered while copying data into " . $self->_cache_copying_directory);
                $self->_caching_cleanup;
                die;
            }

            my $mv_rv = Genome::Utility::FileSystem->shellcmd(
                cmd => "mv " . $self->_cache_copying_directory . " " . $self->_cache_directory
            );
            unless ($mv_rv) {
                $self->error_message("Error encountered while moving data from " . $self->_cache_copying_direcory .
                    " to " . $self->_cache_directory);
                $self->_caching_cleanup;
                die;
            }

            $self->status_message("Caching complete, locally stored at " . $self->_cache_directory);
            return $self->_cache_directory;
        }
    }
}

# Returns transcript iterator object using local data cache (if present) or default location
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
        my ($data_dir) = $self->determine_data_directory;
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

# Recopies any files from the remote directory that are newer or different than local cache
sub _update_cache {
    my $self = shift;
    my @composite_builds = $self->from_builds;
    if (@composite_builds) {
        for (@composite_builds) { $_->_update_cache }
    }
    else {
        my $cp_rv = Genome::Utility::FileSystem->shellcmd(cmd => "cp -Lru " . $self->_annotation_data_directory . "/* " . $self->_cache_directory);
        unless ($cp_rv) {
            $self->error_message("Error encountered while updating cache");
            die;
        }
    }
    return 1;
}

# Location of annotation data cache
sub _cache_directory {
    my $self = shift;
    return "/tmp/cached_annotation_data/" . $self->model_name . "/" . $self->version . "/annotation_data";
}

# Location of cache data during copy
sub _cache_copying_directory {
    my $self = shift;
    return $self->_cache_directory . "_copying";
}

# Location of annotation data in build directory
sub _annotation_data_directory{
    my $self = shift;
    return $self->data_directory . "/annotation_data";
}

# Cleans up any mess left by the caching process
sub _caching_cleanup {
    my $self = shift;
    Genome::Utility::FileSystem->shellcmd(cmd => "rm -rf " . $self->_cache_copying_directory) if -d $self->_cache_copying_directory;
    Genome::Utility::FileSystem->shellcmd(cmd => "rm -rf " . $self->_cache_directory) if -d $self->_cache_directory;
    $self->status_message("Any mess from caching cleaned up");
}

package Genome::Model::ImportedAnnotation::Iterator;
our @ISA = ('UR::Object::Iterator');

sub next {
    my $self = shift;
    return $self->();
}

1;
