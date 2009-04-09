package Genome::Model::Tools::Maq::MapToLayers;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Maq::Map::Reader;

class Genome::Model::Tools::Maq::MapToLayers {
    is => 'Genome::Model::Tools::Maq',
    has => [
            map_file => { is => 'Text'},
            layers_file => { is => 'Text'},
        ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    unless (Genome::Utility::FileSystem->validate_file_for_reading($self->map_file)) {
        $self->error_message('Failed to validata map file for reading '. $self->map_file);
        return;
    }
    unless (Genome::Utility::FileSystem->validate_file_for_writing($self->layers_file)) {
        $self->error_message('Failed to validate layers file for writing '. $self->layers_file);
        return;
    }
    return $self;
}


sub execute {
    my $self = shift;

    my $basename = File::Basename::basename($self->map_file);

    my $map_view_file = Genome::Utility::FileSystem->create_temp_file_path($basename .'.mapview');
    $self->status_message('Mapview file: '. $map_view_file);
    
    my $mapview = Genome::Model::Tools::Maq::Mapview->execute(
                                                              use_version => $self->use_version,
                                                              map_file => $self->map_file,
                                                              output_file => $map_view_file,
                                                          );
    unless ($mapview) {
        $self->error_message('Failed to execute mapview on map file '. $self->map_file);
        return;
    }
    my $mapview_fh = Genome::Utility::FileSystem->open_file_for_reading($mapview->output_file);
    unless ($mapview_fh) {
        $self->error_message('Failed to open mapview file for reading '. $mapview->output_file);
        return;
    }
    my $layers_fh = Genome::Utility::FileSystem->open_file_for_writing($self->layers_file);
    unless ($layers_fh) {
        $self->error_message('Failed to open layers file for writing '. $self->layers_file);
        return;
    }
    while (<$mapview_fh>) {
        chomp;
        my @fields = split("\t",$_);
        my $read_name = $fields[0];
        my $ref_name = $fields[1];
        my $start = $fields[2];
        my $length = $fields[13];
        my $seq = uc($fields[14]);
        my $stop = ($start - $length) - 1;
        print $layers_fh $read_name ."\t". $start ."\t". $stop ."\t". $ref_name ."\t". $seq ."\n";
    }
    $layers_fh->close;
    $mapview_fh->close;
    return 1;
}


1;
