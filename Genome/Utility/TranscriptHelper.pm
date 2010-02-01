package Genome::Utility::TranscriptHelper;

use strict;
use warnings;
use Genome;

class Genome::Utility::TranscriptHelper{
    is => 'UR::Object',
    has => [
        model_name => {
            is => 'Text',
            is_optional => 1,
            default => 'NCBI-human.combined-annotation',
        },
        version => {
            is => 'Text',
            is_optional => 1,
            default => '54_36p',
        }
    ],
};

sub _get_transcript_window {
    # Given a chromosome name, model, and version, returns a transcript window
    my $self = shift;
    my $chromosome = shift;

    my $build = Genome::Model->get(name=>$self->model_name)->build_by_version($self->version);
    my $transcript_iterator = $build->transcript_iterator(chrom_name => $chromosome);

    unless (defined $transcript_iterator) {
        $self->error_message("Could not create transcript iterator for chromosome $chromosome!");
        return;
    }

    my $transcript_window = Genome::Utility::Window::Transcript->create(iterator => $transcript_iterator);

    unless (defined $transcript_window) {
        $self->error_message("Could not create transcript window for chromosome $chromosome!");
        return;
    }

    return $transcript_window;
}

sub annotate_sv {
    # Given a SV type, two chromosomes, and two breakpoints, returns a hash containing information about
    # each breakpoint and, if SV type is DEL, a list of all genes that have been deleted between
    # breakpoint a and breakpoint b
    # Expecting self, type, chrom_a, break_a, chrom_b, break_b
    my $self = shift;
    my $type = shift;
    my @chroms = ($_[0], $_[2]);
    my @breaks = ($_[1], $_[3]);
    my %return_value;

    if ($breaks[0] > $breaks[1] and $chroms[0] eq $chroms[1]) {
        $self->error_message("Breakpoint A should be less than breakpoint B on same chromosome");
        return;
    }
    
    if ($type ne "DEL" and $type ne "INS" and $type ne "INV" and $type ne "CTX") {
        $self->error_message("$type is an invalid event type, valid values are DEL, INS, INV, CTX");
        return;
    }

    if ($chroms[0] ne $chroms[1] and $type ne "CTX") {
        $self->error_message("Only CTX can occur on two different chromosomes");
        return;
    }

    my $transcript_window = $self->_get_transcript_window($chroms[0]);
    return unless defined $transcript_window;
    
    for (my $i = 0; $i <= 1; $i++) {
        $transcript_window = $self->_get_transcript_window($chroms[$i]) if $chroms[$i] ne $chroms[0];
        return unless defined $transcript_window;
        my @transcripts = $transcript_window->scroll($breaks[$i]);
        my %info;
        $info{'transcripts'} = @transcripts? \@transcripts : undef;
        $info{'chromosome'} = $chroms[$i];
        $info{'position'} = $breaks[$i];
        $return_value{'breakpoint_'.$i} = \%info;

        if ($type eq "DEL" and not exists $return_value{'deleted_genes'}) {
            my @deleted_trans = $transcript_window->scroll($breaks[0] + 1, $breaks[1] - 1);
            my %genes;
            for my $t (@deleted_trans) {
                my $gene = $t->gene;
                my $name = $gene->name() if defined $gene;
                $genes{$name}++ if defined $name;
            }
            $return_value{'deleted_genes'} = \%genes;
        }
    }
    return %return_value;
}

sub gene_names_from_transcripts {
    # Given a list of transcripts, returns a hash of the unique corresponding genes and the number of times those genes appear
    my $self = shift;
    my @transcripts = @_;
    return unless @transcripts;
    my %genes;
    for my $t (@transcripts) {
        my $gene = $t->gene;
        my $name = $gene->name() if defined $gene;
        $genes{$name}++ if defined $name;
    }
    return %genes;
}

sub transcripts_at_position {
    # Returns all transcripts at the given position (or range) on the given chromosome
    my $self = shift;
    my ($chrom_name, $start, $stop) = @_;
    unless (defined $chrom_name and defined $start) {
        return;
    }

    if (defined $stop and $start > $stop) {
        $self->error_message("Start position must be less than stop position");
        return;
    }

    my $transcript_window = $self->_get_transcript_window($chrom_name);
    return unless $transcript_window;
    return $transcript_window->scroll($start, $stop);
}

1;

