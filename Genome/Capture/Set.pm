package Genome::Capture::Set;

use strict;
use warnings;

use Genome;

class Genome::Capture::Set {
    table_name => q|
        (select
            setup_name name,
            setup_id id,
            setup_status status,
            setup_description description
        from setup@oltp
        where setup_type = 'setup capture set'
        ) capture_set
    |,
    id_by => [
        id => { },
    ],
    has => {
        name => { },
        description => { },
        status => { },
        _capture_set => {
            doc => 'Solexa Lane Summary from LIMS.',
            is => 'GSC::Setup::CaptureSet',
            calculate => q| GSC::Setup::CaptureSet->get($id); |,
            calculate_from => ['id']
        },
    },
    has_many_optional => {
        set_oligos => {
            is => 'Genome::Capture::SetOligo',
            reverse_as => 'set',
        }
    },
    doc         => '',
    data_source => 'Genome::DataSource::GMSchema',
};

sub bed_file_content {
    my $self = shift;
    my $capture_set = $self->_capture_set;
    my $fs;
    if ($capture_set->file_storage_id) {
        $fs = $capture_set->get_file_storage;
    }
    unless ($fs) {
        return;
    }
    #WARNING: It appears both companies are using 1-based coordinates in the start postion.
    # Actually, NimbleGen has confirmed this: jwalker 05-28-2010
    my @lines = split("\n",$fs->content);
    my $print = 1;
    my $bed_file_content;
    for my $line (@lines) {
        chomp($line);
        if ($line eq 'track name=tiled_region description="NimbleGen Tiled Regions"') {
            $print = 0;
            next;
        } elsif ($line eq 'track name=target_region description="Target Regions"') {
            $print = 1;
            next;
        }
        if ($print) {
            my @entry = split("\t",$line);
            unless (scalar(@entry) >= 3) {
                die('At least three fields are required in BED format files.  Error with line: '. $line);
            }
            $entry[0] =~ s/chr//g;
            unless (defined $entry[3] && $entry[3] ne '') {
                $entry[3] = $entry[0] .':'. $entry[1] .'-'. $entry[2];
            }
            $bed_file_content .= join("\t",@entry) ."\n";
        }
    }
    return $bed_file_content;
}

sub print_bed_file {
    my $self = shift;
    my $bed_file = shift;

    my $one_based_start_position = 1;
    my $bed_file_content = $self->bed_file_content;
    my $barcode = $self->barcode;
    unless ($barcode) {
        $self->error_message('Failed to find barcode.');
        die($self->error_message);
    }
    my $tmp_file = Genome::Utility::FileSystem->create_temp_file_path($barcode .'.bed');
    if ($bed_file_content) {
        my $tmp_fh = Genome::Utility::FileSystem->open_file_for_writing($tmp_file);
        print $tmp_fh $bed_file_content;
        $tmp_fh->close;
    } else {
        my $cmd = '/gsc/scripts/bin/capture_file_dumper --barcode='. $barcode .' --output-type=region-bed --output-file='. $tmp_file;
        Genome::Utility::FileSystem->shellcmd(
            cmd => $cmd,
            output_files => [$tmp_file],
        );
        $one_based_start_position = 0;
    }
    my $tmp_2_file = Genome::Utility::FileSystem->create_temp_file_path($barcode .'-2.bed');
    my $tmp_fh = Genome::Utility::FileSystem->open_file_for_reading($tmp_file);
    my $tmp_2_fh = Genome::Utility::FileSystem->open_file_for_writing($tmp_2_file);
    while (my $line = $tmp_fh->getline) {
        my @entry = split("\t", $line);
        $entry[0] =~ s/chr//g;
        print $tmp_2_fh join("\t",@entry);
    }
    $tmp_fh->close;
    $tmp_2_fh->close;
    my %merge_params = (
        input_file => $tmp_2_file,
        output_file => $bed_file,
        report_names => 1,
    );
    if ($one_based_start_position) {
        $merge_params{maximum_distance} = 1;
    }
    #WARNING: A distance of 1 is used only to compensate for the 1-based start position.  see above WARNING
    unless  (Genome::Model::Tools::BedTools::Merge->execute(%merge_params)) {
        die('Failed to merge BED file with params '. Data::Dumper::Dumper(%merge_params) );
    }
    return 1;
}

sub barcode {
    my $self = shift;
    my $barcode = $self->get_barcode;
    unless ($barcode) { return; }
    return $barcode->barcode;
}

sub get_barcode {
    my $self = shift;
    my $cs = $self->_capture_set;
    return $cs->get_barcode;
}

1;
