package Genome::Disk::Command::Allocation::ArchiveByDate;

use strict;
use warnings;

use Genome;
use DateTime;
use DateTime::Format::Natural;
use DateTime::Format::Oracle;

class Genome::Disk::Command::Allocation::ArchiveByDate {
    is => 'Command::V2',
    has_optional => [
        date => {
            is => 'DateTime',
            doc => 'Allocations older than this date will be archived, defaults ' .
                'to one year before current date. Format should be mm/dd/yyyy',
        },
        disk_group_names => {
            is => 'Text',
            doc => 'Disk groups from which allocations can be archived, comma delimited',
            default_value => 'info_genome_models,info_alignments',
        },
        dry_run => {
            is => 'Boolean',
            doc => 'If set, total number of archivable allocations are found but not archived',
            default => 0,
        },
    ],
};

sub execute {
    my $self = shift;

    my $dt;
    if ($self->date) {
        my $parser = DateTime::Format::Natural->new(format => 'mm/dd/yyyy');
        $dt = $parser->parse_datetime($self->date);
        die "Unable to parser provided date " . $self->date unless $dt;
    }
    else {
        $dt = DateTime->now->subtract(months => 6);
    }
    $ENV{'NLS_TIMESTAMP_FORMAT'} = 'YYYY-MM-DD HH24:MI:SSXFF';
    my $oracle_time_string = DateTime::Format::Oracle->format_datetime($dt);
    $self->status_message("Looking for allocations older than $oracle_time_string");

    my @allocations = Genome::Disk::Allocation->get(
        'creation_time <' => $oracle_time_string,
        archivable => 1,
        disk_group_name => [split(',', $self->disk_group_names)],
    );
    push @allocations, Genome::Disk::Allocation->get(
        creation_time => undef,
        archivable => 1,
        disk_group_name => [split(',', $self->disk_group_names)],
    );

    my $kb;
    for my $allocation (@allocations) {
        $kb += $allocation->kilobytes_requested;
    }
    my $tb = int($kb / (2**30));
    $self->status_message("Found " . scalar @allocations . " allocations that can be archived, totaling $tb TB!");

    return 1 if $self->dry_run;

    for my $allocation (@allocations) {
        next if $allocation->is_archived;
        $self->status_message("Archiving " . $allocation->__display_name__ . "...");
        unless ($allocation->archive) {
            $self->error_message("Failed to archive allocation " . $allocation->__display_name__);
        }
    }

    $self->status_message("Archiving done!");
    return 1;
}

1;

