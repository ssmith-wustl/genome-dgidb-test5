
package Genome::Model::Command::Create;

use strict;
use warnings;

use UR;
use Command; 
use Genome::Model;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        # Steal from the model's properties.
        # TODO: make wrapping a constructor in a command encapsulated.
        sample                      =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The name of the sample whose genome is being modeled", 
                                        },
        dna_type                    =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "Either whole or cdna",
                                        },
        reference_sequence          =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The reference sequence set name to use.  " . 
                                                           "Combined with the DNA type, yields an explicit set of sequences.  " .
                                                           "Defaults to the reference sequence of the prior."
                                        },
        read_calibrator             =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The calibration algorithm to use, if any.", 
                                        },
        aligner                     =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The alignment algorithm to use.", 
                                        },
        
        genotyper                   =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The genotyping algorithm to use.", 
                                        },
        indel_finder                =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The indel finding algorithm to use.", 
                                        },
        prior                       =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The indel finding algorithm to use.", 
                                        },
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
    my @command_properties = qw/sample dna_type read_calibrator aligner genotyper indel_finder prior reference_sequence/;
    
    my $name = 
        join("+", 
            map { defined $_ ? $_ : '' } 
            map { $self->$_ } 
            grep { $_ ne 'reference_sequence' }
            @command_properties
        );

    $name .= '+' . $self->reference_sequence if $self->reference_sequence ne $self->prior;

    my @params = (name => $name);
    for my $command_property (@command_properties) {
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

    unless($obj) {
        $self->error_message("Failed to create genome model: " . $obj->error_message);
        return;
    }
   
    # This is temporary until the object is tied to a real data source. 
    if ($obj->write_to_filesystem()) {
        $self->status_message("Created new model: " . $obj->name);
    }
    else {
        $self->error_message("Failed to write a new model to the filesystem: " . $obj->error_message);
        $obj->delete;
        return;
    }

    return 1;
}

1;

