package Genome::Model::Build::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ImportedAnnotation {
    is => 'Genome::Model::Build',
};

sub annotation_data_directory{
    my $self = shift;
    return $self->data_directory."/annotation_data";
}

sub transcript_iterator{
    my $self = shift;
    my @composite_builds = $self->from_builds; #TODO, implement build links
    if (@composite_builds){
        my @build_ids = map {$_->build_id} @composite_builds;
        my @iterators = map { Genome::Transcript->create_iterator( where => [ build_id => $_ ] ) } @build_ids;
        my @cached_transcripts;
        for (my $i = 0; $i < @iterators; $i++){
            push @cached_transcripts, $iterators[$i]->next;
        }
        my $iterator = sub {
            my $index = 0;
            my $lowest = $cached_transcripts[0];
            for (my $i = 0; $i < @iterators; $i++) {
                next unless $cached_transcripts[$i];
                $lowest ||= $cached_transcripts[$i];
                if ($self->transcript_cmp($cached_transcripts[$i], $lowest) < 0) {
                     $index = $i;
                     $lowest = $cached_transcripts[$index];
                }
            }
            my $next_cache =  $iterators[$index]->next();
            $next_cache ||= '';
            $cached_transcripts[$index] = $next_cache;
            return $lowest;
        };

        bless $iterator, "Genome::Model::ImportedAnnotation::Iterator";
        return $iterator;
    }else{
        return Genome::Transcript->create_iterator(where => [build_id => $self->build_id]);
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

sub Genome::Model::ImportedAnnotation::Iterator::next{
    my $self = shift;
    return $self->();
}

1;
