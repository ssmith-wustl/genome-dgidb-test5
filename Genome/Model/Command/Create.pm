
package Genome::Model::Command::Create;

use strict;
use warnings;

use UR;
use Command; 
use Genome::Model;

use Data::Dumper;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',    
    has => [
        name                    => { is => 'String' },    
        sample                  => { is => 'String' },        
        dna_type                => { is => 'String' },
        genotyper               => { is => 'String' },
        genotyper_params        => { is => 'String', is_optional => 1 },
        indel_finder            => { is => 'String' },
        indel_finder_params     => { is => 'String', is_optional => 1 },
        read_aligner            => { is => 'String' },
        read_aligner_params     => { is => 'String', is_optional => 1 },
        reference_sequence      => { is => 'String' },
    ],
);

sub sub_command_sort_position {
    -1
}

sub help_brief {
    "create a new genome model"
}

sub help_synopsis {
    return <<"EOS"
genome-model create
                    --name ley_aml_1_revA
                    --sample ley_aml_patient1 
                    --dna-type whole 
                    --read-calibrator none
                    --aligner maq1_6    
                    --genotyper maq1_6     
                    --indel-finder bhdsindel1 
                    --prior NCBI-human-build36 
EOS
}

sub help_detail {
    return <<"EOS"

This defines a new genome model.  Currently it equates to a directory tree on the filesystem.

The properties of the model determine what will happen when the add-reads command is run.

EOS
}

sub execute {
    my $self = shift;

    unless ($self->prior) {
        $self->prior('none');
    }

    unless ($self->reference_sequence) {
        if ($self->prior eq "none") {
            $self->error_message("No reference sequence set.  This is required w/o a prior.");
        }
        $self->reference_sequence($self->prior);
    }

    my $target_class = "Genome::Model";    
    my @command_properties = qw/name sample dna_type read_calibrator read_calibrator_params
                                read_aligner read_aligner_params genotyper genotyper_params indel_finder indel_finder_params
                                reference_sequence/;
    
    my @params;
    for my $command_property (@command_properties) {
        $DB::single = 1;
        my $object_property = $command_property;
        if ($target_class->can($command_property . "_name")) {
            $object_property .= "_name";
        }
        elsif ($command_property eq "prior") {
            $object_property = "prior_model_name";
        }
        
        push @params, $object_property => $self->$command_property;
    }
    
    my $obj = Genome::Model->create(@params);
    print Dumper(\@params);

    unless($obj) {
        $self->error_message("Failed to create genome model: " . $obj->error_message);
        return;
    }
    
    unless (UR::Context->commit) {
        $self->error_message("Failed to commit changes");
        return;
    }
    return 1;
}

1;

