
package Genome::Model;

use strict;
use warnings;

use above "Genome";
use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;
use File::Path;
use File::Basename;
use IO::File;
use Sort::Naturally;

class Genome::Model {
    type_name => 'genome model',
    table_name => 'GENOME_MODEL',
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        genome_model_id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        processing_profile           => { is => 'Genome::ProcessingProfile', id_by => 'processing_profile_id' },
        processing_profile_name      => { via => 'processing_profile', to => 'name'},
        type_name                    => { via => 'processing_profile'},
        name                         => { is => 'VARCHAR2', len => 255 },
        sample_name                  => { is => 'VARCHAR2', len => 255 },
        subject_name            => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        events                       => {
                                         is => 'Genome::Model::Event',
                                         is_many => 1,
                                         reverse_id_by => 'model', 
                                         doc => 'all events which have occurred for this model',
                                     },
        creation_event               => { doc => 'The creation event for this model',
                                          calculate => q|
                                                            my @events = $self->events;
                                                            for my $event (@events) {
                                                                if ($event->event_type eq 'genome-model create model') {
                                                                    return $event;
                                                                }
                                                            }
                                                            return undef;
                                                        |
                                        },
        creation_event_inputs        => { doc => 'The inputs specified for the creation event',
                                          via => 'creation_event',
                                          to  => 'inputs',
                                        },
        instrument_data              => { doc       => 'The instrument data specified for the model',
                                          via       => 'creation_event_inputs',
                                          to        => 'value',
                                          where     => [ name => 'instrument_data' ],
                                        },

        test                         => { is => 'Boolean',
                                          doc => 'testing flag',
                                          is_optional => 1,
                                          is_transient => 1,
                                        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'The GENOME_MODEL table represents a particular attempt to model knowledge about a genome with a particular type of evidence, and a specific processing plan. Individual assemblies will reference the model for which they are assembling reads.',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    if ($^P) {
        $self->test(1);
    }
    return $self;
}

# Operating directories

sub base_parent_directory {
    "/gscmnt/839/info/medseq"
}

sub base_model_comparison_directory {
    my $self = shift;
    return $self->base_parent_directory . "/model_comparisons";
}

sub alignment_links_directory {
    my $self = shift;
    return $self->base_parent_directory . "/alignment_links";
}

sub alignment_directory {
    my $self = shift;
    return $self->alignment_links_directory .'/'. $self->read_aligner_name .'/'.
        $self->reference_sequence_name;
}

sub model_links_directory {
    my $self = shift;

	if (defined($ENV{'GENOME_MODEL_TESTDIR'}) &&
		  -e $ENV{'GENOME_MODEL_TESTDIR'}) {
		return $ENV{'GENOME_MODEL_TESTDIR'};
	} else {
    return $self->base_parent_directory . "/model_links";
	}
}

sub data_directory {
    my $self = shift;
    my $name = $self->name;
    return $self->model_links_directory . '/' . $self->sample_name . "_" . $name;
}

# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _resolve_subclass_name {
    my $class = shift;
    my $proper_subclass_name;
    if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
        my $type_name = $_[0]->type_name;
        $proper_subclass_name = $class->_resolve_subclass_name_for_type_name($type_name);
    }
    # access the type according to the processing profile being used
    elsif (my $processing_profile_id = $class->get_rule_for_params(@_)->specified_value_for_property_name('processing_profile_id')) {
        my $processing_profile = Genome::ProcessingProfile->get(id =>
                                            $processing_profile_id);
        my $type_name = $processing_profile->type_name;    
        $proper_subclass_name = $class->_resolve_subclass_name_for_type_name($type_name);
    }
    # Adding a hack to call class to force autoload
    $proper_subclass_name->class if $proper_subclass_name;
    return $proper_subclass_name;
}

# This is called by both of the above.
sub _resolve_subclass_name_for_type_name {
    my ($class,$type_name) = @_;
    my @type_parts = split(' ',$type_name);
    
    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);
    
    my $class_name = join('::', 'Genome::Model' , $subclass);
    return $class_name;
}

sub _resolve_type_name_for_subclass_name {
    my ($class,$subclass_name) = @_;
    my ($ext) = ($subclass_name =~ /Genome::Model::(.*)/);
    return unless ($ext);
    my @words = $ext =~ /[a-z]+|[A-Z](?:[A-Z]+|[a-z]*)(?=$|[A-Z])/g;
    my $type_name = lc(join(" ", @words));
    return $type_name;
}

my @printable_property_names;
sub pretty_print_text {
    my $self = shift;
    unless (@printable_property_names) {
        # do this just once...
        my $class_meta = $self->get_class_object;
        for my $name ($class_meta->all_property_names) {
            next if $name eq 'name';
            my $property_meta = $class_meta->get_property_meta_by_name($name);
            unless ($property_meta->is_delegated or $property_meta->is_calculated) {
                push @printable_property_names, $name;
            }
            # an exception to include the processing profile name when listed
            if ($name eq 'processing_profile_name') {
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
    $out .= Term::ANSIColor::colored(sprintf("Model: %s (ID %s)", $self ->name, $self->id), 'bold magenta') . "\n\n";
    $out .= Term::ANSIColor::colored("Configured Properties:", 'red'). "\n";    
    $out .= join("\n", map { " @$_ " } @out);
    $out .= "\n\n";
    return $out;
}

1;
