package Genome::Model::EventWithRefSeq;

use strict;
use warnings;

use Genome;
use File::Temp;

class Genome::Model::EventWithRefSeq {
    is =>[ 'Genome::Model::Event', 'Genome::Model::Command::MaqSubclasser'],
    is_abstract => 1,
    sub_classification_method_name => '_get_sub_command_class_name',
    has => [
            ref_seq_id        => {
                                  is => 'NUMBER',
                                  len => 11,
                                  doc => "identifies the refseq"
                              },
            cleanup_tmp_files => {
                                  is => 'Boolean',
                                  doc => 'set to force cleanup of your tmp mapmerge'
                              },
    ],
};

sub desc {
    my $self = shift;
    my $desc = $self->SUPER::desc;
    $desc .= " for refseq " . $self->ref_seq_id . " on build " . $self->build_id;
    return $desc;
}

sub resolve_log_directory {
    my $self = shift;
    return sprintf('%s/logs/%s', $self->build_directory,
                                     $self->ref_seq_id);
}

sub DESTROY {
   my $self=shift;

   if($self->cleanup_tmp_files) {
       $self->warning_message("cleanup flag set. Removing files we transferred."); 
       $self->cleanup_my_mapmerge;
   }

   $self->SUPER::DESTROY;
}

sub accumulate_maps {
    my $self = shift;
    return $self->build->accumulate_maps;
}

sub revert {
    my $self = shift;
    my @outputs = $self->outputs;
    for my $output (@outputs) {
        if ($output->name eq 'Hostname') {
            $self->warning_message("Attempting to cleanup a blade /tmp/ file...");
            return unless $self->cleanup_the_mapmerge_I_specify($output);
        }
    }
    return $self->SUPER::revert;
}

1;
