package Genome::Model;

use strict;
use warnings;

use Genome;
use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;
use Genome::Model::FileSystemInfo;

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
        indel_finder_name       => { is => 'varchar(255)', is_optional => 1 },
        indel_finder_params     => { is => 'varchar(255)', is_optional => 1 },
        name                    => { is => 'varchar(255)' },
        prior                   => { is => 'varchar2(255)', is_optional => 1 },
        read_aligner_name       => { is => 'varchar(255)' },
        read_aligner_params     => { is => 'varchar(255)', is_optional => 1 },
        read_calibrator_name    => { is => 'varchar(255)', is_optional => 1 },
        read_calibrator_params  => { is => 'varchar(255)', is_optional => 1 },
        reference_sequence_name => { is => 'varchar(255)' },
        sample_name             => { is => 'varchar(255)' },
    ],
    data_source => 'Genome::DataSource::Main',
);

sub data_parent_directory {
    "/gscmnt/sata114/info/medseq/sample_data"
}

sub data_directory {
    my $self = shift;
    my $name = $self->name;
    return $self->model_data_parent_directory . '/' . $name;
}

sub pretty_print_text {
    my $self = shift;
    
    my @out;
    for my $prop (grep {$_ ne "name"} $self->property_names) {
        if (defined $self->$prop) {
            push @out, [
                Term::ANSIColor::colored($prop, 'red'),
                Term::ANSIColor::colored($self->$prop, "cyan")
            ]
        }
    }
    
    Genome::Model::EqualColumnWidthTableizer->new->convert_table_to_equal_column_widths_in_place( \@out );

    my $out;
    $out .= Term::ANSIColor::colored("Model: " . $self ->name, 'bold magenta'). "\n\n";
    $out .= Term::ANSIColor::colored("Configured Properties:", 'red'). "\n";    
    $out .= join("\n", map { " @$_ " } @out);
    $out .= "\n\n";
    return $out;
}

sub sample_path{
    my $self = shift;
    
    return Genome::Model::FileSystemInfo->new->sample_data_directory . $self->sample_name;
}

1;
