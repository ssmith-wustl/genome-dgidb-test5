package Genome::Capture::Set::Command::Import;

use strict;
use warnings;

use Genome;



class Genome::Capture::Set::Command::Import {
    is => 'Command',
    has_input => [
        bed_file => {
            is => 'Text',
            doc => 'The path to the BED file to import',
        },
        source => {
            is => 'Text',
            doc => 'The source of the capture set bed file',
            valid_values => ['nimblegen','agilent'],
        },
        capture_set_name => {
            is => 'Text',
            doc => 'The name that will be used to uniquely identify this capture set',
        },
    ],
    has_output => [
        capture_set_id => {
            doc => 'The newely created capture set id',
            is_optional => 1,
        }
    ],
};

sub execute {
    my $self = shift;

    my $existing_capture_set = Genome::Capture::Set->get(name => $self->capture_set_name);
    if ($existing_capture_set) {
        die('Found existing capture set by name: '. $existing_capture_set->name .'('. $existing_capture_set->id .')');
    }

    my $bed_fh = Genome::Utility::FileSystem->open_file_for_reading($self->bed_file);
    unless ($bed_fh) {
        die('Failed to open BED file '. $self->bed_file);
    }
    #WARNING: It appears both companies are using 1-based coordinates in the start postion.
    my @lines;
    if ($self->source eq 'nimblegen') {
        my $print;
        while (my $line = $bed_fh->getline) {
            chomp($line);
            if ($line eq 'track name=tiled_region description="NimbleGen Tiled Regions"') {
                $print = 0;
                next;
            } elsif ($line eq 'track name=target_region description="Target Regions"') {
                $print = 1;
                next;
            }
            if ($print) {
                push @lines, $line;
            }
        }
    } else {
        while (my $line = $bed_fh->getline) {
            chomp($line);
            push @lines, $line;
        }
    }
    $bed_fh->close;
    # NOTE: All these for loops and iterating through the files multiple times is in-efficient to say the least
    my @corrected_lines;
    for my $line (@lines) {
        my @entry = split("\t",$line);
        unless (scalar(@entry) >= 3) {
            die('At least three fields are required in BED format files.  Error with line: '. $line);
        }
        unless (defined $entry[3] && $entry[3] ne '') {
            $entry[3] = $entry[0] .':'. $entry[1] .'-'. $entry[2];
        }
        push @corrected_lines, join("\t",@entry);
    }
    my ($output_fh,$output_file) = Genome::Utility::FileSystem->create_temp_file('pre_merged.bed');
    for my $line (@corrected_lines) {
        print $output_fh $line ."\n";
    }
    $output_fh->close;

    my $merged_output_file = Genome::Utility::FileSystem->create_temp_file_path('merged.bed');
    #WARNING: A distance of 1 is used only to compensate for the 1-based start position.  see above WARNING
    unless  (Genome::Model::Tools::BedTools::Merge->execute(
        input_file => $output_file,
        output_file => $merged_output_file,
        maximum_distance => 1,
        report_names => 1,
    )) {
        die('Failed to merge BED file '. $output_file);
    }
    my $cmd = '/gsc/scripts/bin/execute_create_capture_container --bed-file='. $merged_output_file .' --setup-name=\''. $self->capture_set_name .'\'';
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
    );
    return 1;
}


1;

