package Genome::Model::Tools::OldRefCov::Run;

use strict;
use warnings;

use Genome;

use RefCov;

class Genome::Model::Tools::OldRefCov::Run {
    is => ['Genome::Model::Tools::OldRefCov','Genome::Sys'],

};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    unless ($self->output_directory) {
        require Cwd;
        my $cwd = Cwd::cwd();
        $self->output_directory($cwd);
    }

    unless ($self->create_directory($self->output_directory)) {
        $self->error_message('Failed to create output directory '. $self->output_directory);
        die($self->error_message);
    }
    unless ($self->validate_directory_for_write_access($self->output_directory)) {
        $self->error_message('Failed to validate directory for writing '. $self->output_directory);
        die($self->error_message);
    }
    unless ($self->validate_file_for_reading($self->layers_file_path)) {
        $self->error_message('Failed to validate file for reading '. $self->layers_file_path);
        die($self->error_message);
    }
    unless ($self->validate_file_for_reading($self->genes_file_path)) {
        $self->error_message('Failed to validate file for reading '. $self->genes_file_path);
        die($self->error_message);
    }
    if (-e $self->log_file_path) {
        unless (unlink $self->log_file_path) {
            $self->error_message('Failed to remove existing log file '. $self->log_file_path .":  $!");
            die($self->error_message);
        }
    }
    return $self;
}


sub execute {
    my $self = shift;

    my $log_fh = $self->open_file_for_writing($self->log_file_path);
    unless ($log_fh) {
        $self->error_message('Failed to open log file for writing '. $self->log_file_path);
        return;
    }

    my $genes_fh = $self->open_file_for_reading($self->genes_file_path);
    unless ($genes_fh) {
        $self->error_message('Failed to open genes file for reading '. $self->genes_file_path);
        return;
    }
    # Load and hold all GENES
    my @genes;
    while (<$genes_fh>) {
        chomp;
        push (@genes, $_);
    }
    $genes_fh->close;

    my $genes_number = scalar @genes;
    $self->status_message("LOADED genes.... $genes_number");

    print $log_fh UR::Time->now() ."\n";

    # Build and hold objects now.
    my %object;
    foreach my $gene (@genes) {
        my ($gene_name, $start, $stop, $parent) = split (/\t/, $gene);
        my $myRefCov = RefCov->new(
                                   name  => $gene_name,
                                   start => $start,
                                   stop  => $stop,
                               );
        $object{$gene_name} = $myRefCov;
    }
    my $object_number = keys %object;
    $self->status_message("INITIALIZED refcov objects.... $object_number");

    print $log_fh UR::Time->now() ."\n";

    # Layer reads.
    my $layers_fh = $self->open_file_for_reading($self->layers_file_path);
    unless ($layers_fh) {
        $self->error_message('Failed to open layers file for reading '. $self->layers_file_path);
        return;
    }
    while (<$layers_fh>) {
        chomp;
        my ($read, $start, $stop, $ref, $seq) = split (/\t/, $_);
        if ($object{$ref}) {
            $object{$ref}->layer_read(
                                      layer_name => $read,
                                      start      => $start,
                                      stop       => $stop,
                                      redundancy => 1, 
                                  );
        }
        else {
            #print $log_fh "Had to skip $ref!!!\n";
        }
    }
    $layers_fh->close;

    $self->status_message('LOADED all layers onto refcov objects....');
    print $log_fh UR::Time->now() ."\n";

    # Save files to disk; make STATS report.
    unless ($self->create_directory($self->frozen_directory)) {
        $self->error_message('Failed to create frozen directory '. $self->frozen_directory);
        return;
    }

    my $stats_fh = $self->open_file_for_writing($self->stats_file_path);
    unless ($stats_fh) {
        $self->error_message('Failed to open stats file for writing '. $self->stats_file_path);
        return;
    }
    foreach my $loaded_object (keys %object) {
        print $log_fh "stats for: $loaded_object\n";
        $object{$loaded_object}->freezer( $self->frozen_directory .'/__'. $loaded_object );
        print $stats_fh join ("\t", $loaded_object, @{ $object{$loaded_object}->generate_stats() }, ) ."\n";
    }
    $self->status_message('SAVED objects.... FINISHED!!!!!');
    print $log_fh UR::Time->now() ."\n";
    $stats_fh->close;
    $log_fh->close;
    return 1;
}

1;
