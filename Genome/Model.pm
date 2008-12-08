package Genome::Model;

use strict;
use warnings;

use Genome;

use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;
use Genome::Model::Tools::Maq::RemovePcrArtifacts;
require Genome::Utility::FileSystem;
use File::Path;
use Cwd;
use File::Basename;
use IO::File;
use Sort::Naturally;
use YAML;
use Archive::Tar;

class Genome::Model {
    type_name => 'genome model',
    table_name => 'GENOME_MODEL',
    is_abstract => 1,
    first_sub_classification_method_name => '_resolve_subclass_name',
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        genome_model_id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        read_sets =>  { is => 'Genome::Model::ReadSet', reverse_id_by => 'model', is_many=> 1 },
        builds => { is => 'Genome::Model::Command::Build', reverse_id_by => 'model', is_many => 1 },
        run_chunks => { is => 'Genome::RunChunk', via=>'read_sets', to => 'read_set' },
        current_running_build_id => {is => 'NUMBER' , len => 10 },
        last_complete_build_id => {is => 'NUMBER', len=> 10 },
        data_directory               => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
        processing_profile           => { is => 'Genome::ProcessingProfile', id_by => 'processing_profile_id' },
        processing_profile_name      => { via => 'processing_profile', to => 'name'},
        type_name                    => { via => 'processing_profile'},
        name                         => { is => 'VARCHAR2', len => 255 },
        subject_name                 => { is => 'VARCHAR2', len => 255 },
        subject_type                 => { is => 'VARCHAR2', len => 255 },
        events                       => {
            is => 'Genome::Model::Event',
            is_many => 1,
            reverse_id_by => 'model', 
            doc => 'all events which have occurred for this model',
        },
        creation_event               => { 
            doc => 'The creation event for this model',
            calculate => q|
            my @events = $self->events;
            for my $event (@events) {
            if ($event->event_type eq 'genome-model create model') {
                return $event;
                }
            }
            return undef;|,
            doc => 'The creation event for this model' 
    },
    test                          => { is => 'Boolean', is_optional => 1, is_transient => 1, doc => 'testing flag' },
    _printable_property_names_ref => { is => 'array_ref', is_optional => 1, is_transient => 1, 
        doc => 'calculate all property names once' },
    comparable_normal_model_id    => { is => 'NUMBER', len => 10, is_optional => 1 },
    sample_name                   => { is => 'VARCHAR2', len => 255, is_optional => 1 },
    ],
    has_many => [
    project_assignments => { is => 'Genome::Model::ProjectAssignment', reverse_id_by => 'model' },
    projects            => { is => 'Genome::Project', via => 'project_assignments', to => 'project' },
    project_names       => { is => 'Text', via => 'projects', to => 'name' },

    #< Instrument data >#
    instrument_data => { 
        is => 'Genome::InstrumentData', 
        via => 'instrument_data_assignments',
        to => 'instrument_data' 
    },
    assigned_instrument_data => { # same as instrument_data
        is => 'Genome::InstrumentData', 
        via => 'instrument_data_assignments',
        to => 'instrument_data' 
    },
    instrument_data_assignments => { 
        is => 'Genome::Model::InstrumentDataAssignment', 
        reverse_id_by => 'model',
        is_many => 1,
    },
    built_instrument_data => {
        calculate => q| 
        return map { $_->instrument_data } grep { defined $_->first_build_id } $self->instrument_data_assignments;
        |,
    },
    unbuilt_instrument_data => {
        calculate => q| 
        return map { $_->instrument_data } grep { !defined $_->first_build_id } $self->instrument_data_assignments;
        |,
    },
    instrument_data_assignment_events => {
        is => 'Genome::Model::Command::AssignInstrumentData',
        is_many => 1,
        reverse_id_by => 'model',
        doc => 'Each case of an instrument data being assigned to the model',
    },
    # old instrument data stuff that lnked to read sets
    instrument_data_links        => { is => 'Genome::Model::ReadSet', is_many => 1, reverse_id_by => 'model', is_mutable => 1, 
        doc => "for models which directly address instrument data, the list of assigned run chunks"
    },
    _instrument_data              => { via => 'instrument_data_links', to => 'read_set_id', is_mutable => 1 },
    #<>#
    ],
    has_optional => [
    current_running_build     => { is => 'Genome::Model::Command::Build', id_by => 'current_running_build_id' },
    input_read_set_class_name => { calculate_from => 'read_set_class_name',
        calculate => q($read_set_class_name->_dw_class), 
        doc => 'the class of read set assignable to this model in the dw' },
    read_set_addition_events  => { is => 'Genome::Model::Command::AddReads', reverse_id_by => 'model', is_many => 1, 
        doc => 'each case of a read set being assigned to the model' },
    read_set_class_name       => { calculate_from => 'sequencing_platform',
        calculate => q( 'Genome::RunChunk::' . ucfirst($sequencing_platform) ), 
        doc => 'the class of read set assignable to this model' },
        sequencing_platform       => { via => 'processing_profile' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'The GENOME_MODEL table represents a particular attempt to model knowledge about a genome with a particular type of evidence, and a specific processing plan. Individual assemblies will reference the model for which they are assembling reads.',
};

sub create {
    my $class = shift;
    
    my $self = $class->SUPER::create(@_)
        or return;

    # Verify subject_type
    unless ( grep { $self->subject_type eq $_ } subject_types() ) {
        $self->error_message(
            sprintf(
                "Invalid subject type (%s), please select from:\n %s",
                $self->subject_type,
                join("\n ", subject_types()), 
            )
        );
        $self->SUPER::delete;
        return;
    }
    
    # Verify subjects
    unless ( $self->_verify_subjects ) {
        $self->SUPER::delete;
        return;
    }
    
    # If data directory has not been supplied, figure it out
    unless ($self->data_directory) {
        $self->data_directory( $self->resolve_data_directory );
    }

    return $self;
}

#< Subjects >#
my %SUBJECT_TYPES = (
    species_name => {
        needs_to_be_verified => 1,
        class => 'Genome::Taxon',
        property => 'species_name',
    },
    sample_name => {
        needs_to_be_verified => 1,
        class => 'Genome::Sample',
        property => 'name',
    },
    genomic_dna => {
                    needs_to_be_verified => 1,
                    class => 'Genome::Sample::Genomic',
                    property => 'name',
                },
    sample_group => {
        needs_to_be_verified => 0,
        #class => 'Genome::Sample',
        #property => 'name',
    },
    dna_resource_item_name => {
        needs_to_be_verified => 0,
        #class => 'Genome::Sample',
        #property => 'name',
    },
);
sub subject_types {
    return keys %SUBJECT_TYPES;
}

sub subject_type_class {
    return $SUBJECT_TYPES{ $_[0]->subject_type }->{class};
}

sub subject_type_property {
    return $SUBJECT_TYPES{ $_[0]->subject_type }->{property};
}

sub need_to_verify_subjects_for_type {
    return $SUBJECT_TYPES{ $_[0]->subject_type }->{needs_to_be_verified};
}

sub get_subjects {
    my $self = shift;

    my $subject_class = $self->subject_type_class;
    my $subject_property = $self->subject_type_property;

    return $subject_class->get(
        $subject_property => $self->subject_name,
    );
}

sub _verify_subjects {
    my $self = shift;

    return 1 unless $self->need_to_verify_subjects_for_type;

    my @subjects = $self->get_subjects;
    unless ( @subjects ) {
        my $subject_class = $self->subject_type_class;
        my $subject_property = $self->subject_type_property;
        $self->error_message( 
            sprintf(
                "No subjects with %s (%s) found.\nPossible subjects for type (%s) include:\n %s\nPlease select from the above", 
                $subject_property,
                $self->subject_name,
                $self->subject_type,
                join("\n ", sort map { $_->$subject_property } $subject_class->get()),
            ) 
        );
        return;
    }

    return @subjects;
}

sub get_all_possible_sample_names { # 
    my $self = shift;

    my @sample_names;
    if ( $self->subject_type eq 'species_name' ) {
        my $taxon = Genome::Taxon->get(species_name => $self->subject_name);
        @sample_names = map { $_->name } $taxon->samples;
    }
    else {
        @sample_names = ( $self->subject_name );
    }

    return @sample_names
}

#< Instrument Data >#
#TODO move to class def, if possible
sub compatible_instrument_data {
    my $self = shift;

    #TODO: This is a hack for 454 variant detection
    if ($self->subject_type eq 'genomic_dna' &&
        $self->sequencing_platform eq '454' &&
        $self->type_name eq 'reference alignment') {
        my $dna = GSC::DNA->get(dna_name => $self->subject_name);
        if ($dna) {
            my @seq_ids = map { $_->region_id } GSC::RunRegion454->search_runs_for_sample($dna);
            if (scalar(@seq_ids)) {
                return Genome::InstrumentData->get(id => \@seq_ids);
            }
        }
    }

    my %params = (
                  sample_name => [ $self->get_all_possible_sample_names ],
              );
    $params{sequencing_platform} = $self->sequencing_platform if $self->sequencing_platform;
    return Genome::InstrumentData->get(%params);
}

sub available_instrument_data { return unassigned_instrument_data(@_); }
sub unassigned_instrument_data {
    my $self = shift;

    my @compatible_instrument_data = $self->compatible_instrument_data;
    my @instrument_data_assignments = $self->instrument_data_assignments 
        or return @compatible_instrument_data;
    my %assigned_instrument_data_ids = map { $_->instrument_data_id => 1 } @instrument_data_assignments;

    return grep { not $assigned_instrument_data_ids{$_->id} } @compatible_instrument_data;
}

sub dump_unbuilt_instrument_data_to_filesysytem {
    my $self = shift;

    my @unbuilt_instrument_data = $self->unbuilt_instrument_data;
    unless ( @unbuilt_instrument_data ) {
        $self->status_message(
            sprintf('No unbuilt instrument data found (<id> %s <name> %s)', $self->id, $self->name) 
        );
        return;
    }

    my $chromat_dir = $self->consed_directory->chromat_dir;
    
    for my $instrument_data ( @unbuilt_instrument_data ) { 
        $self->status_message(
            sprintf('Dumping instrument data (<id> %s <name> %s)', $instrument_data->id, $instrument_data->run_name) 
        );
        $instrument_data->dump_to_file_system
            or return;
        
        my $instrument_data_dir = $instrument_data->full_path;
        my $dh = IO::Dir->new($instrument_data_dir);
        unless ( $dh ) {
            $self->error_message("Can'\t open directory ($instrument_data_dir)");
            return;
        }

        while ( my $trace = $dh->read ) {
            next if $trace =~ m#^\.#;
            my $target = sprintf('%s/%s', $instrument_data_dir, $trace);
            my $link = sprintf('%s/%s', $chromat_dir, $trace);
            Genome::Utility::FileSystem->create_symlink($target, $link)
                or return;
        }
    }

    return 1;
}

#<>#
sub compatible_input_items {
    my $self = shift;

    my $input_read_set_class_name = $self->input_read_set_class_name;
    my $value_ref;
    if ($self->subject_type eq 'species_name') {
        my $taxon = Genome::Taxon->get(species_name => $self->subject_name);
        my @samples = $taxon->samples;
        $value_ref = [ map { $_->name } @samples ];

    } elsif ($self->subject_type eq 'sample_name') {
        $value_ref = {
                      operator => "like",
                      value => $self->subject_name
                  };
    } elsif ( $self->subject_type eq 'genomic_dna') {
        $value_ref =  $self->subject_name;
    } elsif ($self->subject_type eq 'dna_resource_item_name') {
        $self->error_message('Please implement compatible_input_items in '.
                             __PACKAGE__ .' for subject_type(dna_resource_item_name)');
        die;
    }

    unless ($value_ref) {
        $self->error_message('No value to get compatible input read sets');
        die;
    }
    my %instrument_data_ids;
    my @sample_read_sets = $input_read_set_class_name->get(
                                                           sample_name => $value_ref,
                                                       );
    %instrument_data_ids = map { $_->id => 1 } @sample_read_sets;
    if ($input_read_set_class_name eq 'GSC::RunRegion454') {
        my @dna_read_sets = $input_read_set_class_name->get(
                                                            incoming_dna_name => $value_ref,
                                                        );
        if ($self->subject_type eq 'genomic_dna') {
            my $dna = GSC::DNA->get(dna_name => $value_ref);
            if ($dna) {
                push @dna_read_sets, $input_read_set_class_name->search_runs_for_sample($dna);
            }
        }
        for (@dna_read_sets) {
            $instrument_data_ids{$_->id} = 1;
        }
    }
    my @input_read_sets;
    my @instrument_data_ids = keys %instrument_data_ids;
    @input_read_sets = GSC::Sequence::Item->get(\@instrument_data_ids);
    #TODO: move
    if ($input_read_set_class_name eq 'GSC::RunLaneSolexa') {
        @input_read_sets = grep { $_->run_type !~ /1/  } @input_read_sets;
    }
    return @input_read_sets;
}

sub available_read_sets {
    my $self = shift;

    my @input_read_sets = $self->compatible_input_items;
    my @read_sets = $self->read_sets;
    my %prior = map { $_->read_set_id => 1 } @read_sets;
    my @available_read_sets = grep { not $prior{$_->id} } @input_read_sets;
    return @available_read_sets;
}

sub unbuilt_read_sets {
    my $self = shift;

    my @read_sets = $self->read_sets;
    my @unbuilt_read_sets = grep { !defined($_->first_build_id) } @read_sets;
    return @unbuilt_read_sets;
}

sub built_read_sets {
    my $self = shift;

    my @read_sets = $self->read_sets;
    my @built_read_sets = grep { $_->first_build_id} @read_sets;
    return @built_read_sets;
}


sub last_complete_build {
    my $self=shift;
    if (defined $self->last_complete_build_id ) {
        return Genome::Model::Command::Build->get($self->last_complete_build_id);
    }
    return;
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

# This is the directory for model data, alignment data, model comparison data, etc.
sub base_parent_directory {
    "/gscmnt/sata363/info/medseq"
}

# This directory should never contain data
# only symlinks to the data directories across the filesystem
sub model_links_directory {
    return '/gscmnt/839/info/medseq/model_links';
}

sub alignment_links_directory {
    return '/gscmnt/839/info/medseq/alignment_links';
}

sub base_model_comparison_directory {
    my $self = shift;
    return "/gscmnt/839/info/medseq/model_comparisons";
}

sub alignment_directory {
    my $self = shift;
    return $self->alignment_links_directory .'/'. $self->read_aligner_name .'/'.
        $self->reference_sequence_name;
}

# This is actual data directory on the filesystem
# Currently the disk is hard coded in base_parent_directory
sub model_data_directory {
    my $self = shift;

    if (defined($ENV{'GENOME_MODEL_TESTDIR'}) &&
    -e $ENV{'GENOME_MODEL_TESTDIR'}) {
        return $ENV{'GENOME_MODEL_TESTDIR'};
    } else {
        return $self->base_parent_directory .'/model_data';
    }
}

# This is a human readable(model_name) symlink to the model_id based symlink
# This symlink is created so humans can find their data on the filesystem
sub model_link {
    my $self = shift;
    die sprintf("Model (ID: %s) does not have a name\n", $self->id) unless defined $self->name;
    return $self->model_links_directory .'/'. $self->name;
}

# This is the model_id based directory where the model data will be stored
sub resolve_data_directory {
    my $self = shift;
    return $self->model_data_directory . '/' . $self->id;
}

sub resolve_archive_file {
    my $self = shift;
    return $self->model_data_directory .'/'. $self->id .'.tbz';
}

sub latest_build_directory {
    my $self = shift;
    if (defined $self->current_running_build_id) {
        my $build = Genome::Model::Command::Build->get($self->current_running_build_id);
        return $build->data_directory;
    } elsif (defined $self->last_complete_build_id) {
        my $build = Genome::Model::Command::Build->get($self->last_complete_build_id);
        return $build->data_directory;
    } else {
       die "no builds found";
    }
}

sub resolve_reports_directory {
    my $self=shift;
    my $build_dir = $self->latest_build_directory;
    return $build_dir . "/reports/";
}

sub available_reports {
    my $self=shift;
    my $report_dir = $self->resolve_reports_directory;
    my %report_file_hash;
    my @report_subdirs = glob("$report_dir/*");
    my @reports;
    for my $subdir (@report_subdirs) {
        #we may be able to do away with touching generating class and just try to find reports that match this subdir name? not sure
        my ($report_name) = ($subdir =~ /\/+reports\/+(.*)\/*/);
        push @reports, Genome::Model::Report->create(model_id => $self->id, name => $report_name);
    }
    return \@reports; 
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

sub pretty_print_text {
    my $self = shift;
    unless (defined $self->_printable_property_names_ref) {
        # do this just once...
        my @props;
        my $class_meta = $self->get_class_object;
        for my $name ($class_meta->all_property_names) {
            next if $name eq 'name';
            my $property_meta = $class_meta->get_property_meta_by_name($name);
            unless ($property_meta->is_delegated or $property_meta->is_calculated) {
                push @props, $name;
            }
            # an exception to include the processing profile name when listed
            if ($name eq 'processing_profile_name') {
                push @props, $name;
            }
        }
        $self->_printable_property_names_ref(\@props);
    }
    my @printable_property_names = @{$self->_printable_property_names_ref};
    unless (@printable_property_names){
        $self->error_message("Can't generate property names from ".ref $self);
        return;
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

sub get_all_objects {
    my $self = shift;

    my @read_sets = $self->read_sets;
    if ($read_sets[0] && $read_sets[0]->id =~ /^\-/) {
        @read_sets = sort {$b->id cmp $a->id} @read_sets;
    } else {
        @read_sets = sort {$a->id cmp $b->id} @read_sets;
    }

    my @builds = $self->builds;
    if ($builds[0] && $builds[0]->id =~ /^\-/) {
        @builds = sort {$b->id cmp $a->id} @builds;
    } else {
        @builds = sort {$a->id cmp $b->id} @builds;
    }
    return (@read_sets, @builds);
}

sub yaml_string {
    my $self = shift;
    my $string = YAML::Dump($self);
    my @objects = $self->get_all_objects;
    for my $object (@objects) {
        #Need to implement a method for read_set and event
        $string .= $object->yaml_string;
    }
    return $string;
}

sub delete {
    my $self = shift;

    my $data_directory = $self->data_directory;
    my $db_objects_dump_file = $data_directory .'/data_dump.yaml';
    my $fh = IO::File->new($db_objects_dump_file,'w');
    unless ($fh) {
        $self->error_message('Failed to create file handle for file '. $db_objects_dump_file);
        return;
    }
    print $fh $self->yaml_string;
    $fh->close;

    my $cwd = getcwd;
    my ($filename,$dirname) = File::Basename::fileparse($data_directory);
    $filename =~ s/^-/\.\/-/;
    unless (chdir $dirname) {
        $self->error_message('Failed to change directories to '. $dirname);
        return;
    }
    my $cmd = 'tar --bzip2 --preserve --create --file '. $self->resolve_archive_file .' '. $filename;
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message('Failed to create archive of model '. $self->id .' with command '. $cmd);
        return;
    }
    unless (chdir $cwd) {
        $self->error_message('Failed to change directories to '. $cwd);
        return;
    }

    my @objects = $self->get_all_objects;
    for my $object (@objects) {
        unless ($object->delete) {
            $self->error_message('Failed to remove object '. $object->class .' '. $object->id);
            return;
        }
    }
    if (-e $self->data_directory) {
        unless (rmtree $self->data_directory) {
            $self->warning_message('Failed to rmtree model data directory '. $self->data_directory);
        }
    }
    if (-l $self->model_link) {
        unless (unlink($self->model_link)) {
            $self->warning_message('Failed to remove model link '. $self->model_link);
        }
    } else {
        if (-e $self->model_link) {
            $self->warning_message('Expected symlink for the model link but got path'. $self->model_link);
            $self->warning_message('Remove the model directory path manually if desired');
        }
    }
    $self->SUPER::delete;
    return 1;
}



1;

#$HeadURL$
#$Id$
