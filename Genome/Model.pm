
package Genome::Model;

use strict;
use warnings;

use Genome;
use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;
use Genome::Model::Tools::Maq::RemovePcrArtifacts;
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
        read_sets =>  { is => 'Genome::Model::ReadSet', reverse_id_by => 'model', is_many=> 1 },
        run_chunks => { is => 'Genome::RunChunk', via=>'read_sets', to=>'runchunk' },

        data_directory               => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
        processing_profile           => { is => 'Genome::ProcessingProfile', id_by => 'processing_profile_id' },
        processing_profile_name      => { via => 'processing_profile', to => 'name'},
        type_name                    => { via => 'processing_profile'},
        name                         => { is => 'VARCHAR2', len => 255 },
        sample_name                  => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        subject_name                 => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        instrument_data_links        => { is => 'Genome::Model::ReadSet', is_many => 1, reverse_id_by => 'model', is_mutable => 1, 
                                            doc => "for models which directly address instrument data, the list of assigned run chunks"
                                        },
        instrument_data              => { via => 'instrument_data_links', to => 'read_set_id', is_mutable => 1 },
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
        test                         => { is => 'Boolean',
                                          doc => 'testing flag',
                                          is_optional => 1,
                                          is_transient => 1,
                                        },
    ],
    has_optional => {
                     sequencing_platform          => { via => 'processing_profile'},
                     read_set_class_name          => {
                                                      calculate_from => ['sequencing_platform'],
                                                      calculate => q| 'Genome::RunChunk::' . ucfirst($sequencing_platform) |,
                                                      doc => 'the class of read set assignable to this model'
                                                  },
                     input_read_set_class_name    => { 
                                                      calculate_from => ['read_set_class_name'],
                                                      calculate => q|$read_set_class_name->_dw_class|,
                                                      doc => 'the class of read set assignable to this model in the dw'
                                        },
                     read_set_addition_events     => { is => 'Genome::Model::Command::AddReads',
                                                       is_many => 1,
                                                       reverse_id_by => 'model',
                                                       doc => 'each case of a read set being assigned to the model',
                                                  },
    },
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
    if ($self->sample_name && $self->subject_name) {
        die ('No support for both sample_name and subject_name');
    }

    # If data directory has not been supplied, figure it out
    unless ($self->data_directory) {
        $self->data_directory($self->resolve_data_directory);
    }

    
    return $self;
}

sub compatible_input_read_sets {
    my $self = shift;

    my $input_read_set_class_name = $self->input_read_set_class_name;
    my $sample_name = $self->subject_name || $self->sample_name;
    my @input_read_sets = $input_read_set_class_name->get(sample_name => $sample_name);

    #TODO: move
    if ($input_read_set_class_name eq 'GSC::RunLaneSolexa') {
        @input_read_sets = grep { $_->run_type !~ /1/  } @input_read_sets;
    }
    return @input_read_sets;
}

sub available_read_sets {
    my $self = shift;

    my @input_read_sets = $self->compatible_input_read_sets;
    my @read_sets = $self->read_sets;
    my %prior = map { $_->read_set_id => 1 } @read_sets;
    my @available_read_sets = grep { not $prior{$_->id} } @input_read_sets;
    return @available_read_sets;
}

sub unbuilt_read_sets {
    my $self = shift;

    my @read_sets = $self->read_sets;
    my @unbuilt_read_sets = grep {!defined($_->first_build_id)} @read_sets;
    return @unbuilt_read_sets;
}


sub comparable_normal_model {
    # TODO: a dba ticket is in place to make this a database-tracked item
    my $self = shift;
    my $name = $self->model->name;
    return unless $name =~ /tumor/;
    unless ($name =~ s/tumor98/tumor34/) {
       unless ($name =~ s/tumor/skin/) {
            die "error finding normal for $name!";
        }
    }
    my $other = Genome::Model->get(name => $name);
    die unless ($other);
    return $other;
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
sub resolve_data_directory {
    my $self = shift;
    my $name = $self->name;
    my $subject_name = $self->subject_name || $self->sample_name;
    my $base_dir =$self->model_links_directory . '/' . $subject_name . "_" . $name;
    return $base_dir;
}

sub latest_build_directory {
    my $self = shift;
    my $name = $self->name;
    #FIXME: LOOKUP LATEST BUILD
    my $subject_name = $self->subject_name || $self->sample_name;
    my $base_dir =$self->model_links_directory . '/' . $subject_name . "_" . $name;
    if(my @builds = Genome::Model::Command::Build->get(model_id=>$self->id)) {
        @builds = sort {$a->build_id <=> $b->build_id} @builds;
        $base_dir .= '/build' . $builds[-1]->build_id;
    }
    return $base_dir;
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

sub lock_directory {
    my $self = shift;
    my $data_directory = $self->latest_build_directory;
    my $lock_directory = $data_directory . '/locks/';
    if (-d $data_directory and not -d $lock_directory) {
        mkdir $lock_directory;
        chmod 02775, $lock_directory;
    }
    return $lock_directory;
}

sub lock_resource {
    my($self,%args) = @_;
    $self->warning_message("locking is disabled since the new build system circumvents the need for it");
    #$self->warning_message(Carp::longmess());
    return 1;

    my $ret;
    my $resource_id = $self->lock_directory . '/' . $args{'resource_id'} . ".lock";
    my $block_sleep = $args{block_sleep} || 60;
    my $max_try = $args{max_try} || 7200;

    mkdir($self->lock_directory,0777) unless (-d $self->lock_directory);

    while(! ($ret = mkdir $resource_id)) {
        return undef unless $max_try--;
        $self->status_message("waiting on lock for resource $resource_id");
        sleep $block_sleep;
    }

    my $lock_info_pathname = $resource_id . '/info';
    my $lock_info = IO::File->new(">$lock_info_pathname");
    $lock_info->printf("HOST %s\nPID $$\nLSF_JOB_ID %s\nUSER %s\n",
                       $ENV{'HOST'},
                       $ENV{'LSB_JOBID'},
                       $ENV{'USER'},
                     );
    $lock_info->close();

    eval "END { unlink \$lock_info_pathname; rmdir \$resource_id;}";

    return 1;
}

sub unlock_resource {
    my ($self, %args) = @_;
    my $resource_id = delete $args{resource_id};
    Carp::confess("No resource_id specified for unlocking.") unless $resource_id;
    $resource_id = $self->lock_directory . "/" . $resource_id . ".lock";
    unlink $resource_id . '/info';
    rmdir $resource_id;
}
1;
