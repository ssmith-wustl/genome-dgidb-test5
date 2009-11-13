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

sub annotation_data_directory{
    my $self = shift;
    return $self->data_directory."/annotation_data";
}

sub transcript_iterator{
    my $self = shift;
    my %p = @_;

    my $chrom_name = $p{chrom_name};

    my @composite_builds = $self->from_builds; #TODO, implement build links
    if (@composite_builds){
        my @data_directories = map {$_->annotation_data_directory} @composite_builds;
        my @iterators;
        if ($chrom_name){
            @iterators = map { Genome::Transcript->create_iterator( where => [ data_directory => $_ , chrom_name => $chrom_name ] ) } @data_directories;
        }else{
            @iterators = map { Genome::Transcript->create_iterator( where => [ data_directory => $_ ] ) } @data_directories;
        }
        my @cached_transcripts;
        for (my $i = 0; $i < @iterators; $i++){
            push @cached_transcripts, $iterators[$i]->next;
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
        if ($chrom_name){
            return Genome::Transcript->create_iterator(where => [data_directory => $self->annotation_data_directory, chrom_name => $chrom_name]);
        }else{
            return Genome::Transcript->create_iterator(where => [data_directory => $self->annotation_data_directory]);
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

package Genome::Model::ImportedAnnotation::Iterator;
our @ISA = ('UR::Object::Iterator');

sub next {
    my $self = shift;
    return $self->();
}

1;
