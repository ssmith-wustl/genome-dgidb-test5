package Genome::Model;

use strict;
use warnings;

use Genome;
use Term::ANSIColor;

use Genome;
UR::Object::Class->define(
    class_name => 'Genome::Model',
    english_name => 'genome model',
    table_name => 'genome_model',
    id_by => [
        id => { is => 'integer' },
    ],
    has => [
        dna_type                => { is => 'varchar(255)' },
        genotyper_name          => { is => 'varchar(255)' },
        genotyper_params        => { is => 'varchar(255)', is_optional => 1 },
        indel_finder_name       => { is => 'varchar(255)' },
        indel_finder_params     => { is => 'varchar(255)', is_optional => 1 },
        name                    => { is => 'varchar(255)' },
        read_aligner_name       => { is => 'varchar(255)' },
        read_aligner_params     => { is => 'varchar(255)', is_optional => 1 },
        read_calibrator_name    => { is => 'varchar(255)', is_optional => 1 },
        read_calibrator_params  => { is => 'varchar(255)', is_optional => 1 },
        reference_sequence_name => { is => 'varchar(255)' },
        sample_name             => { is => 'varchar(255)' },
    ],
    schema_name => 'Main',
    data_source => 'Genome::DataSource::Main',
);

sub pretty_print_text {
    my $self = shift;

    my $out;

    $out .= Term::ANSIColor::colored("Model: " . $self ->name, 'bold red'). "\n\n";
    $out .= Term::ANSIColor::colored("Configured Properties:", 'bold red'). "\n";

    for my $prop (grep {$_ ne "name"} $self->property_names) {
        
        if (defined $self->$prop) {

            $out .= "\t" . Term::ANSIColor::colored($prop, 'bold red'). "\t\t";
            $out .= Term::ANSIColor::colored($self->$prop, "red"). "\n";
        }
    }

    $out .= "\n\n";
}


1;
