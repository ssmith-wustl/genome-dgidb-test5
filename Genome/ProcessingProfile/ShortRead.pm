package Genome::ProcessingProfile::ShortRead;

use strict;
use warnings;

use above "Genome";
class Genome::ProcessingProfile::ShortRead {
    type_name => 'processing profile short read',
    table_name => 'PROCESSING_PROFILE_SHORT_READ',
	is => 'Genome::ProcessingProfile', 
    id_by => [
        id                 => { is => 'NUMBER', len => 11 },
    ],
    has => [
        align_dist_threshold         => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        dna_type                     => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        genotyper_name               => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        genotyper_params             => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        indel_finder_name            => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        indel_finder_params          => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        multi_read_fragment_strategy => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        prior_ref_seq                => { is => 'VARCHAR2', len => 255, is_optional => 1 }, 
        read_aligner_name            => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        read_aligner_params          => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        read_calibrator_name         => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        read_calibrator_params       => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        reference_sequence_name      => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        sequencing_platform          => { is => 'VARCHAR2', len => 255, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

my @printable_property_names;
sub pretty_print_text {
    my $self = shift;
    unless (@printable_property_names) {
        # do this just once...
        my $class_meta = $self->get_class_object;
        for my $name ($class_meta->all_property_names) {
            next if $name eq 'name';
            print $name,"\n";
            my $property_meta = $class_meta->get_property_meta_by_name($name);
            unless ($property_meta->is_delegated or $property_meta->is_calculated) {
                push @printable_property_names, $name;
            }
        }
    }
    my @out;
    for my $prop (@printable_property_names) {
        if (my @values = $self->$prop) {
            my $value;
            if (@values > 1) {
                if (grep { ref($_) } @values) {
                    next;
                }
                $value = join(", ", grep { defined $_ } @values);
            }
            else {
                $value = $values[0];
            }
            next if not defined $value;
            next if ref $value;
            next if $value eq '';
            
            push @out, [
                Term::ANSIColor::colored($prop, 'red'),
                Term::ANSIColor::colored($value, "cyan")
            ]
        }
    }
    
    Genome::Model::EqualColumnWidthTableizer->new->convert_table_to_equal_column_widths_in_place( \@out );

    my $out;
    $out .= Term::ANSIColor::colored(sprintf("Processing Profile: %s (ID %s)", $self ->name, $self->id), 'bold magenta') . "\n\n";
    $out .= Term::ANSIColor::colored("Configured Properties:", 'red'). "\n";    
    $out .= join("\n", map { " @$_ " } @out);
    $out .= "\n\n";
    return $out;
}

1;
