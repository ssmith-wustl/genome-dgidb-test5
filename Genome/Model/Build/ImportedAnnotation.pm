package Genome::Model::Build::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ImportedAnnotation {
    is => 'Genome::Model::Build',
    has => [
        version => { 
            via => 'inputs', 
            to => 'value_id', 
            where => [ name => 'version'], 
            is_mutable => 1 
        },
        annotation_data_source_directory => {
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'annotation_data_source_directory' ],
            is_mutable => 1 
        },
        species_name => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'species_name' ],
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
        my $data_dir = $self->_annotation_data_directory;
        if (-d $self->_cache_copying_directory){
            $self->status_message("Caching in progress (".$self->_cache_copying_directory."), using annotation data dir at " . $data_dir);
            return $data_dir;
        }
        if (-d $self->_cache_directory){
            $self->status_message("Annotation data already cached at ".$self->_cache_directory);
            return $self->_cache_directory;
        }

        $self->status_message("Caching annotation data locally");
        my $mkdir_rv = system("mkdir -p " . $self->_cache_copying_directory);
        if ($mkdir_rv == 0) {
            $self->status_message("Directory created at " . $self->_cache_copying_directory . ", starting copy from " . $data_dir);
            my $cp_rv = system("cp -Lr " . $data_dir . "/* " . $self->_cache_copying_directory);
            if ($cp_rv == 0) {
                $self->status_message("Annotation data directory copied, moving to " . $self->_cache_directory);
                my $mv_rv = system("mv " . $self->_cache_copying_directory ." ". $self->_cache_directory);
                if ($mv_rv == 0) {
                    $self->status_message("Created annotation data cache at " . $self->_cache_directory);
                    return $self->_cache_directory;
                }
            }
        }

        system("rm -rf " . $self->_cache_copying_directory) if -d $self->_cache_copying_directory;
        system("rm -rf " . $self->_cache_directory) if -d $self->_cache_directory;
        $self->warning_message("Could not create annotation data cache at " . $self->_cache_directory . ", using data at " . $data_dir);
        return $data_dir;
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
        my @cached_transcripts;
        for my $i (@iterators) {
            push @cached_transcripts, $i->next;
        }
        my $iterator = sub {
            my $index;
            my $lowest;
            for (my $i = 0; $i < @iterators; $i++) {
                next unless $cached_transcripts[$i];
                unless ($lowest){
                    $lowest = $cached_transcripts[$i];
                    $index = $i;
                }
                if ($self->transcript_cmp($cached_transcripts[$i], $lowest) < 0) {
                    $index = $i;
                    $lowest = $cached_transcripts[$index];
                }
            }
            unless (defined $index){
                #here we have exhausted both iterators
                return undef;
            }
            my $next_cache =  $iterators[$index]->next();
            $next_cache ||= '';
            $cached_transcripts[$index] = $next_cache;
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


package Genome::Model::ImportedAnnotation::Iterator;
our @ISA = ('UR::Object::Iterator');

sub next {
    my $self = shift;
    return $self->();
}

1;
