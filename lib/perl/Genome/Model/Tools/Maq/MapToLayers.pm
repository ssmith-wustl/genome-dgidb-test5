package Genome::Model::Tools::Maq::MapToLayers;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Maq::Map::Reader;

class Genome::Model::Tools::Maq::MapToLayers {
    is => ['Genome::Model::Tools::Maq','Genome::Sys'],
    has => [
            map_file => { is => 'Text'},
            layers_file => { is => 'Text'},
        ],
    has_optional => [
                     randomize => {
                                   is => 'Boolean',
                                   doc => 'run shuf to randomize the reads',
                                   default_value => 0,
                               },
                 ]
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    unless ($self->validate_file_for_reading($self->map_file)) {
        $self->error_message('Failed to validata map file for reading '. $self->map_file);
        return;
    }
    unless ($self->validate_file_for_writing($self->layers_file)) {
        $self->error_message('Failed to validate layers file for writing '. $self->layers_file);
        return;
    }
    return $self;
}


sub execute {
    my $self = shift;

    my $basename = File::Basename::basename($self->map_file);

    my $map_view_file = $self->create_temp_file_path($basename .'.mapview');
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
    my $mapview_fh = $self->open_file_for_reading($mapview->output_file);
    unless ($mapview_fh) {
        $self->error_message('Failed to open mapview file for reading '. $mapview->output_file);
        return;
    }


    my $layers_fh = $self->open_file_for_writing($self->layers_file);
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
        my $stop = ($start + $length) - 1;
        print $layers_fh $read_name ."\t". $start ."\t". $stop ."\t". $ref_name ."\t". $seq ."\n";
    }
    $layers_fh->close;
    $mapview_fh->close;
    my $file_to_copy;
    if ($self->randomize) {
        my $random_file = $self->create_temp_file_path($basename .'.randomized');
        my $cmd = '/gsc/pkg/coreutils/coreutils-6.10-64/shuf -o '. $random_file .' '. $self->layers_file;
        $self->shellcmd(
                                              cmd => $cmd,
                                              input_files => [$self->layers_file],
                                              output_files => [$random_file],
                                          );
        unless (unlink $self->layers_file) {
            $self->error_message('Failed to remove un-randomized layers file'. $self->layers_file .": $!");
            die($self->error_message);
        }
        unless ($self->copy_file($random_file,$self->layers_file)) {
            $self->error_message('Failed to copy randomized file '. $random_file .' to output layers file '. $self->layers_file .":  $!");
            die($self->error_message);
        }
    }
    return 1;
}


1;
