
package Genome::Model;

use strict;
use warnings;

use UR;
use IO::File;
use Carp;

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


our $BASE_DIR = "/gscmnt/sata114/info/medseq/";

sub sample_base_directory {
    my $self = shift;
    return "$BASE_DIR/sample_data";
}

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

use YAML;
sub write_to_filesystem {
    my $self = shift;
    print YAML::Dump($self);
    print "\n";
    print "sample directory = " . $self->sample_directory . "\n";
}

our $RUNS_LIST_FILE = $BASE_DIR . 'aml/run_listing.txt';
sub get_runs_info {
    my($class) = @_;

    my $retval = {};
    
    # Format is one record per line, each line is tab seperated
    # run number, comma sep list of lanes, bustard path for run, sample data path for run
    my $f = IO::File->new($RUNS_LIST_FILE);
    unless ($f) {
        Carp::croak("Can't open runs list file $RUNS_LIST_FILE for reading: $!");
    }

    while(<$f>) {
        s/#.*$//;  # Remove comments
        next unless (m/\w/);    # skip lines with no content

        my($run, $lanes, $bustard, $sample) = split(/\t/, $_);
        my @lanes = split(/,/,$lanes);

        $retval->{$run} = { lanes => \@lanes,
                            bustard_path => $bustard,
                            sample_path => $sample,
                          }
    }
    return $retval;
}


sub add_run_info {
    my($class, %params) = @_;

    my $run_number = $params{'run_number'};
    unless ($run_number) {
        Carp::croak("run_number is a required param to add_run_info");
    }

    my $existing = $class->get_runs_info();
    if (exists $existing->{$run_number}) {
        Carp::confess("A run already exists with number $run_number, appending the new data to the end of the file");
    }

    my $f = IO::File->new(">>$RUNS_LIST_FILE");
    unless ($f) {
        Carp::croak("Can't open runs list file $RUNS_LIST_FILE for append: $!");
    }

    my $lanes_str = '';
    if (ref($params{'lanes'}) eq 'ARRAY') {
        $lanes_str = join(',',@{$params{'lanes'}});
    } else {
        $lanes_str = $params{'lanes'};
    }

    $f->printf('%s\t%s\t%s\t%s\n',
               $run_number,
               $lanes_str,
               $params{'bustard_path'},
               $params{'sample_path'},
             );
}

1;

