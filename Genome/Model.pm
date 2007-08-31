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
    schema_name => 'Main',
    data_source => 'Genome::DataSource::Main',
);

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
    _make_table_columns_equal_width(\@out);

    my $out;
    $out .= Term::ANSIColor::colored("Model: " . $self ->name, 'red'). "\n\n";
    $out .= Term::ANSIColor::colored("Configured Properties:", 'red'). "\n";    
    $out .= join("\n", map { " @$_ " } @out);
    $out .= "\n\n";
    return $out;
}

sub _make_table_columns_equal_width {
    my $arrayref = shift;
    my @max_length;
    for my $row (@$arrayref) {
        for my $col_num (0..$#$row) {
            $max_length[$col_num] ||= 0;
            if ($max_length[$col_num] < length($row->[$col_num])) {                
                $max_length[$col_num] = length($row->[$col_num]);
            }
        }
    }
    for my $row (@$arrayref) {
        for my $col_num (0..$#$row) {
            $row->[$col_num] .= ' ' x ($max_length[$col_num] - length($row->[$col_num]) + 1);
        }
    }    
}
1;
