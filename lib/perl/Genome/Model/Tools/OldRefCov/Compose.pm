package Genome::Model::Tools::OldRefCov::Compose;

use strict;
use warnings;

use Genome;

use RefCov::Reference;

class Genome::Model::Tools::OldRefCov::Compose {
    is => ['Command'],
    has_input => [
                  snapshot_directories => {
                                           is => 'List',
                                           doc => 'The snapshot directories to compose',
                                       },
                  composed_directory => {
                                         is => 'Text',
                                         doc => 'The path to where the composed objects should live',
                                     },
              ],
};

sub execute {
    my $self = shift;

    my $prior_directory;
    for my $snapshot_directory (@{$self->snapshot_directories}) {
        unless (-d $snapshot_directory) { die ('Snapshot directory '. $snapshot_directory .' is not a directory!'); }
        my $snapshot_basename = File::Basename::basename($snapshot_directory);
        unless ($prior_directory) {
            $prior_directory = $snapshot_directory;
            next;
        }
        my $prior_basename= File::Basename::basename($prior_directory);
        my $composed_basename = $prior_basename .'_'. $snapshot_basename;
        my $composed_directory = $self->composed_directory .'/'. $composed_basename;

        $self->compose_two_to_one($prior_directory,$snapshot_directory,$composed_directory);
        $prior_directory = $composed_directory;
    }
    return 1;
}

sub compose_two_to_one {
    my $self = shift;
    my $first_directory = shift;
    my $second_directory = shift;
    my $composed_directory = shift;

    unless (Genome::Sys->create_directory($composed_directory)) {
        $self->error_message('Failed to create directory '. $composed_directory);
        die($self->error_message);
    }

    my $first_stats = $first_directory .'/STATS.tsv';
    my $second_stats = $second_directory .'/STATS.tsv';
    my $composed_stats  = $composed_directory .'/STATS.tsv';

    my $first_frozen = $first_directory .'/FROZEN';
    my $second_frozen = $second_directory .'/FROZEN';
    my $composed_frozen = $composed_directory .'/FROZEN';

    unless (Genome::Sys->create_directory($composed_frozen)) {
        $self->error_message('Failed to create composed frozen directory '. $composed_frozen .":  $!");
        die($self->error_message);
    }
    my %transcripts;
    for my $stats_file ($first_stats, $second_stats) {
        my $parser = $self->get_stats_parser($stats_file);
        while (my %fields = $parser->next) {
            $transcripts{$fields{0}} = 1;
        }
    }
    my $composed_stats_fh = Genome::Sys->open_file_for_writing($composed_stats);
    for my $transcript (keys %transcripts) {
        my $first_transcript = $first_frozen .'/__'. $transcript .'.rc';
        my $second_transcript = $second_frozen .'/__'. $transcript .'.rc';

        my $ref;
        if (!-f $first_transcript && !-f $second_transcript) {
            die('No files found for either transcript: '. $first_transcript .' or '. $second_transcript);
        } elsif (-f $first_transcript  && !-f $second_transcript) {
            $ref = RefCov::Reference->new(thaw => $first_transcript);
        } elsif( !-f $first_transcript && -f $second_transcript) {
            $ref = RefCov::Reference->new(thaw => $second_transcript);
        } else {
            $ref = RefCov::Reference->new(thaw_compose => [$first_transcript,$second_transcript]);
        }
        unless ($ref) {
            $self->error_message('Failed to thaw compose the ref cov object for transcripts '. $first_transcript .' and '. $second_transcript);
            die($self->error_message);
        }
        # the .rc extension gets appended by ref-cov
        $ref->freezer($composed_frozen .'/__'. $transcript);
        print $composed_stats_fh join ("\t", $ref->name, @{ $ref->generate_stats() }, ) ."\n";
    }
    $composed_stats_fh->close;
    return 1;
}

sub get_stats_parser {
    my $self = shift;
    my $stats_file = shift;
    my @header_fields = (0 .. 17);
    my $parser = Genome::Utility::Parser->create(
                                                 file => $stats_file,
                                                 separator => "\t",
                                                 header => 0,
                                                 header_fields => \@header_fields,
                                             );
    unless ($parser) {
        $self->error_message('Failed to create tab delimited parser for stats file '. $stats_file);
        die($self->error_message);
    }
    return $parser;
}
