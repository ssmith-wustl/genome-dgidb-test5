
package Genome::Model;

use strict;
use warnings;

use UR;
use IO::File;
use Carp;
use YAML;
use Genome::Model::FileSystemInfo;
use Genome::Model::Runs;

UR::Object::Class->define(
    class_name  => __PACKAGE__,
    id_by       => ['name'],
    has         => [    
        name                        =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The name of this model.  Unique.", 
                                        },

        sample_name                 =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The name of the sample whose genome is being modeled", 
                                        },

        dna_type                    =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "Either whole or cdna",
                                        },
                                            
        reference_sequence_name     =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The reference sequence set name to use.  " . 
                                                           "Combined with the DNA type, yields an explicit set of sequences.", 
                                        },

        read_calibrator_name        =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The calibration algorithm to use, if any.", 
                                        },

        aligner_name                =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The alignment algorithm to use.", 
                                        },

        
        genotyper_name              =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The genotyping algorithm to use.", 
                                        },
        
        indel_finder_name           =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The indel finding algorithm to use.", 
                                        },
        
        prior_model_name            =>  {   type        => "String",
                                            is_optional => 0,
                                            doc         => "The indel finding algorithm to use.", 
                                        },
    ]
);

# Class Methods --------------------------------------------------------------

our $FILESYSTEM_INFO = Genome::Model::FileSystemInfo->new();
our $BASE_DIR = $FILESYSTEM_INFO->base_directory(); 
our $RUNS_LIST_FILE = $FILESYSTEM_INFO->runs_list_filename();

sub get_runs_info {
    return Genome::Model::Runs->new()->get_runs_info();
} 

sub sample_base_directory {
    return "$BASE_DIR/sample_data";
}

sub add_run_info {
    my($class, %params) = @_;

    my $runs = Genome::Model::Runs->new();

    $runs->add_run_info(%params);
}

# Instance Methods -----------------------------------------------------------------

sub sample_directory {
    my $self = shift;
    return $self->sample_base_directory . '/' . $self->sample_name;
}

sub genome_model_base_directory {
    my $self = shift;
    return $self->sample_directory . '/genome-models';
}

sub genome_model_directory {
    my $self = shift;
    my $shorter_name = $self->name;
    $shorter_name =~ s/^.*?\+//;
    return $self->genome_model_base_directory . '/' . $shorter_name;
}

sub write_to_filesystem {
    my $self = shift;
    print YAML::Dump($self);
    print "\n";
    print "sample directory = " . $self->sample_directory . "\n";
}

1;

