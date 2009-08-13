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

our %SUBJECT_TYPES;

class Genome::Model {
    type_name => 'genome model',
    table_name => 'GENOME_MODEL',
    is_abstract => 1,
    first_sub_classification_method_name => '_resolve_subclass_name',
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        genome_model_id => { is => 'Number', len => 11 },
    ],
    has => [
        name                    => { is => 'Text', len => 255 },
        data_directory          => { is => 'Text', len => 1000, is_optional => 1 },
        subject_name            => { is => 'Text', len => 255 },
        subject_type            => { is => 'Text', len => 255, 
                                     valid_values => [keys %SUBJECT_TYPES] },
        auto_assign_inst_data   => { is => 'Number', len => 4, is_optional => 1 },
        auto_build_alignments   => { is => 'Number', len => 4, is_optional => 1 },
        subject                 => { calculate_from => [ 'subject_name', 'subject_type' ],
                         calculate => q( 
                                                if (not defined $subject_type) {
                                                    # this should not happen
                                                    return;
                                                }
                                                elsif ($subject_type eq 'dna_resource_item_name') {
                                                    # wtf is this?
                                                    return GSC::DNAResourceItem->get(dna_name => $subject_name);
                                                }
                                                elsif ($subject_type eq 'genomic_dna') {
                                                    # 454 issue with 
                                                    return;
                                                    die "not sure how to handle sample type $subject_type";
                                                }
                                                elsif ($subject_type eq 'sample_name') {
                                                    return Genome::Sample->get(name => $subject_name);
                                                }
                                                elsif ($subject_type eq 'species_name') {
                                                    return Genome::Taxon->get(species_name => $subject_name); 
                                                }
                                                elsif ($subject_type eq 'sample_group') {
                                                    return;
                                                    die "not sure how to handle sample type $subject_type";
                                                }
                                                elsif ($subject_type eq 'library_name') {
                                                    return;
                                                    die "not sure how to handle sample type $subject_type";
                                                }
                                                else {
                                                    die "unknown sample type $subject_type!";
                                                }
                                            ) },
        processing_profile      => { is => 'Genome::ProcessingProfile', id_by => 'processing_profile_id' },
        processing_profile_name => { via => 'processing_profile', to => 'name' },
        type_name               => { via => 'processing_profile' },
        events                  => { is => 'Genome::Model::Event', reverse_id_by => 'model', is_many => 1, 
                         doc => 'all events which have occurred for this model' },
        subject_class_name      => { is => 'VARCHAR2', len => 500, is_optional => 1 },
        subject_id              => { is => 'NUMBER', len => 15, is_optional => 1 },
    ],
    has_optional => [
        user_name                        => { is => 'VARCHAR2', len => 64 },
        creation_date                    => { is => 'TIMESTAMP', len => 6 },
        builds                           => { is => 'Genome::Model::Build', reverse_id_by => 'model', is_many => 1 },
        gold_snp_path                    => { via => 'attributes', to => 'value', where => [ property_name => 'gold_snp_path', entity_class_name => 'Genome::Model' ], is_mutable => 1 },
        input_instrument_data_class_name => { calculate_from => 'instrument_data_class_name',
                         calculate => q($instrument_data_class_name->_dw_class), 
                         doc => 'the class of instrument_data assignable to this model in the dw' },
        instrument_data_class_name       => { calculate_from => 'sequencing_platform',
                         calculate => q( 'Genome::InstrumentData::' . ucfirst($sequencing_platform) ), 
                         doc => 'the class of instrument data assignable to this model' },
        test                             => { is => 'Boolean', is_transient => 1, 
                         doc => 'testing flag' },
        _printable_property_names_ref    => { is => 'array_ref', is_transient => 1 },
        comparable_normal_model_id       => { is => 'Number', len => 10 },
        sample_name                      => { is => 'Text', len => 255 },
        sequencing_platform              => { via => 'processing_profile' },
        last_complete_build_directory    => { is_calculated => 1, calculate => q|$b = $self->last_complete_build; return unless $b; return $b->data_directory| },
    ],
    has_many_optional => [
        ref_seqs                          => { is => 'Genome::Model::RefSeq', reverse_id_by => 'model' },
        project_assignments               => { is => 'Genome::Model::ProjectAssignment', reverse_id_by => 'model' },
        projects                          => { is => 'Genome::Project', via => 'project_assignments', to => 'project' },
        project_names                     => { is => 'Text', via => 'projects', to => 'name' },
        attributes                        => { is => 'Genome::MiscAttribute', reverse_id_by => '_model', where => [ entity_class_name => 'Genome::Model' ] },
        instrument_data                   => { is => 'Genome::InstrumentData', via => 'instrument_data_assignments' },
        assigned_instrument_data          => { is => 'Genome::InstrumentData', via => 'instrument_data_assignments', to => 'instrument_data' },
        instrument_data_assignments       => { is => 'Genome::Model::InstrumentDataAssignment', reverse_id_by => 'model' },
        built_instrument_data             => { calculate => q( 
            return map { $_->instrument_data } grep { defined $_->first_build_id } $self->instrument_data_assignments;
            ) },
        unbuilt_instrument_data           => { calculate => q( 
            return map { $_->instrument_data } grep { !defined $_->first_build_id } $self->instrument_data_assignments;
            ) },
        instrument_data_assignment_events => { is => 'Genome::Model::Command::InstrumentData::Assign', reverse_id_by => 'model', 
                         doc => 'Each case of an instrument data being assigned to the model' },

        from_model_links                  => { is => 'Genome::Model::Link',
                                               reverse_id_by => 'to_model',
                                               doc => 'bridge table entries where this is the "to" model(used to retrieve models this model is "from")'
                                           },
        from_models                       => { is => 'Genome::Model',
                                               via => 'from_model_links', to => 'from_model',
                                               doc => 'Genome models that contribute "to" this model',
                                           },
        to_model_links                    => { is => 'Genome::Model::Link',
                                               reverse_id_by => 'from_model',
                                               doc => 'bridge entries where this is the "from" model(used to retrieve models models this model is "to")'
                                           },
        to_models                         => { is => 'Genome::Model',
                                               via => 'to_model_links', to => 'to_model',
                                               doc => 'Genome models this model contributes "to"',
                                           },
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
    unless ( $self->subject_type ) {
        $self->error_message("No subject type given.");
        return;
    }

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

    unless ($self->user_name) {
        $self->user_name($ENV{USER});
    }
    unless ($self->creation_date) {
        $self->creation_date(UR::Time->now);
    }

    # If data directory has not been supplied, figure it out
    unless ($self->data_directory) {
        $self->data_directory( $self->resolve_data_directory );
    }

    unless ( $self->_build_model_filesystem_paths() ) {
        $self->error_message('Filesystem path creation failed');
        return;
    }
                                 
    return $self;
}

BEGIN {  # This is ugly when its above the class definition, but I need it to happen first.
#< Subjects >#
    %SUBJECT_TYPES = (
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
        library_name => {
            needs_to_be_verified => 1,
            class => 'Genome::InstrumentData',
            property => 'library_name',
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
        flow_cell_id => {
	    needs_to_be_verified => 1,
	    class => 'Genome::InstrumentData::Solexa',
	    property => 'flow_cell_id',
	},
    );
};

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
    } elsif (
        $self->subject_type eq 'flow_cell_id' ||
            $self->subject_type eq 'library_name'
        ) {
        return;
    } else {
        @sample_names = ( $self->subject_name );
    }

    return @sample_names
}

#< Instrument Data >#
#TODO move to class def, if possible
sub compatible_instrument_data {
    my $self = shift;
    my %params;

    my $subject_type_class;
    #TODO: This is a hack for 454 variant detection
    if ($self->subject_type eq 'genomic_dna' &&
        $self->sequencing_platform eq '454' &&
        $self->type_name eq 'reference alignment') {
        my $dna = GSC::DNA->get(dna_name => $self->subject_name);
        if ($dna) {
            my @rr454 = GSC::RunRegion454->search_runs_for_sample($dna);
            my @seq_ids;
            for my $rr454 ( @rr454 ) {
                my @genomic_dna = $rr454->get_dna_from_library('genomic dna');
                unless (scalar(@genomic_dna) == 1 && $genomic_dna[0]->dna_name eq $self->subject_name) {
                    next;
                }
                push @seq_ids, $rr454->region_id;
            }
            if (scalar(@seq_ids)) {
                %params = (id => \@seq_ids);
            }
        }
    } elsif ($self->get_all_possible_sample_names)  {
        %params = (
                   sample_name => [ $self->get_all_possible_sample_names ],
               );
        $params{sequencing_platform} = $self->sequencing_platform if $self->sequencing_platform;
    } else {
        %params = (
                   $self->subject_type => $self->subject_name,
               );
        $subject_type_class = $self->subject_type_class;
    }
    unless ($subject_type_class) {
        $subject_type_class = 'Genome::InstrumentData';
    }
    return $subject_type_class->get(%params);
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

#<>#
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

# TODO: remove these since they're not supposed to vary on a per-model basis.
sub base_parent_directory {
    return Genome::Config->root_directory;
}

sub model_links_directory {
    return Genome::Config->model_links_directory;
}

sub alignment_links_directory {
    return Genome::Config->alignment_links_directory;;
}

sub base_model_comparison_directory {
    return Genome::Config->model_comparison_link_directory;
}

sub model_data_directory {
    return Genome::Config->model_data_directory;
}


# This is a human readable(model_name) symlink to the model_id based symlink
# This symlink is created so humans can find their data on the filesystem
sub model_link {
    my $self = shift;
    die sprintf("Model (ID: %s) does not have a name\n", $self->id) unless defined $self->name;

    # strip out path separator chars because those will cause symlink creation to fail!
    my $sanitized_name = $self->name;
    $sanitized_name =~ s/\//_/g;
    return Genome::Config->model_links_directory .'/'. $sanitized_name;
}

# These vary based on the current configuration, which could vary over
# time.  This value is set when the model is created if not specified by the creator.
sub resolve_data_directory {
    my $self = shift;
    return Genome::Config->model_data_directory . '/' . $self->id;
}

sub resolve_archive_file {
    my $self = shift;
    return $self->data_directory . '.tbz';
}

sub succeeded_builds {
    my $self = shift;
    my @builds = $self->builds;
    unless (scalar(@builds)) {
        return;
    }

    my @builds_w_status = grep { $_->build_status } @builds;
    unless (@builds_w_status) {
        return;
    }
    my @succeeded_builds = grep {$_->build_status eq 'Succeeded'} grep { defined($_) } @builds_w_status;
    unless (@succeeded_builds) {
        return;
    }
    my @builds_wo_date = grep { !$_->date_completed } @succeeded_builds;
    if (scalar(@builds_wo_date)) {
        my $error_message = 'Found '. scalar(@builds_wo_date) .' Succeeded builds without date completed.' ."\n";
        for (@builds_wo_date) {
            $error_message .= "\t". $_->desc ."\n";
        }
        die($error_message);
    }
    my @sorted_succeeded_builds = sort {$a->date_completed cmp $b->date_completed} @succeeded_builds;
    return @sorted_succeeded_builds;
}

sub last_succeeded_build {
    my $self = shift;

    my @succeeded_builds = $self->succeeded_builds;
    my $last_succeeded_build = pop(@succeeded_builds);
    return $last_succeeded_build;
}

sub last_succeeded_build_id {
    my $self = shift;

    my $last_succeeded_build = $self->last_succeeded_build;
    unless ($last_succeeded_build) {
        return;
    }
    return $last_succeeded_build->id;
}

sub completed_builds {
    my $self = shift;
    my @builds = $self->builds;
    unless (@builds) {
        return;
    }
    my @builds_w_status = grep { $_->build_status } @builds;
    unless (@builds_w_status) {
        return;
    }
    my @completed_builds = grep { $_->date_completed } grep { defined($_) } @builds_w_status;
    unless (@completed_builds) {
        return;
    }
    my @sorted_completed_builds = sort { $a->date_completed cmp $b->date_completed } @completed_builds;
    return @sorted_completed_builds;
}

sub last_complete_build {
    my $self = shift;

    my @completed_builds = $self->completed_builds;
    my $last_complete_build = pop(@completed_builds);
    return $last_complete_build;
}

sub last_complete_build_id {
    my $self = shift;

    my $last_complete_build = $self->last_complete_build;
    unless ($last_complete_build) {
        return;
    }
    return $last_complete_build->id;
}

sub running_builds {
    my $self = shift;
    my @builds = $self->builds;
    unless (scalar(@builds)) {
        return;
    }
    my @builds_w_status = grep { $_->build_status } @builds;
    my @running_builds = grep {$_->build_status eq 'Running'} @builds_w_status;
    my @builds_wo_date = grep { !$_->date_scheduled } @running_builds;
    if (scalar(@builds_wo_date)) {
        my $error_message = 'Found '. scalar(@builds_wo_date) .' Running builds without date scheduled.' ."\n";
        for (@builds_wo_date) {
            $error_message .= "\t". $_->desc ."\n";
        }
        die($error_message);
    }
    my @sorted_running_builds = sort {$a->date_scheduled cmp $b->date_scheduled} @running_builds;
    return @sorted_running_builds;
}

sub current_running_build {
    my $self = shift;

    my @running_builds = $self->running_builds;
    my $current_running_build = pop(@running_builds);
    return $current_running_build;
}

sub current_running_build_id {
    my $self = shift;

    my $current_running_build = $self->current_running_build;
    unless ($current_running_build) {
        return;
    }
    return $current_running_build->id;
}

sub latest_build_directory {
    my $self = shift;
    my $current_running_build = $self->current_running_build;
    if (defined $current_running_build) {
        return $current_running_build->data_directory;
    }
    my $last_complete_build = $self->last_complete_build;
    if (defined $last_complete_build) {
        return $last_complete_build->data_directory;
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
    #if we don't have a completed build, we don't have reports
    $self->last_complete_build and return $self->last_complete_build->available_reports or
    return {};
    $DB::single = 1;
    my $report_dir = $self->resolve_reports_directory;
    my %report_file_hash;
    my @report_subdirs = glob("$report_dir/*");
    my @reports;
    for my $subdir (@report_subdirs) {
        #we may be able to do away with touching generating class and just try to find reports that match this subdir name? not sure
        my ($report_name) = ($subdir =~ /\/+reports\/+(.*)\/*/);
        print ($report_name . "<br>");
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
            my $property_meta = $class_meta->property_meta_for_name($name);
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

sub get_all_objects {
    my $self = shift;

    my @idas = $self->instrument_data_assignments;
    if ($idas[0] && $idas[0]->id =~ /^\-/) {
        @idas = sort {$b->id cmp $a->id} @idas;
    } else {
        @idas = sort {$a->id cmp $b->id} @idas;
    }

    my @builds = $self->builds;
    if ($builds[0] && $builds[0]->id =~ /^\-/) {
        @builds = sort {$b->id cmp $a->id} @builds;
    } else {
        @builds = sort {$a->id cmp $b->id} @builds;
    }
    return ( @idas, @builds );
}

sub yaml_string {
    my $self = shift;
    my $string = YAML::Dump($self);
    my @objects = $self->get_all_objects;
    for my $object (@objects) {
        $string .= $object->yaml_string;
    }
    return $string;
}

sub add_to_model{
    my $self = shift;
    my (%params) = @_;
    my $model = delete $params{to_model};
    my $role = delete $params{role};
    $role||='member';
   
    $self->error_message("no to_model provided!") and die unless $model;
    my $from_id = $self->id;
    my $to_id = $model->id;
    unless( $to_id and $from_id){
        $self->error_message ( "no value for this model(from_model) id: <$from_id> or to_model id: <$to_id>");
        die;
    }
    my $reverse_bridge = Genome::Model::Link->get(from_model_id => $to_id, to_model_id => $from_id);
    if ($reverse_bridge){
        my $string =  "A model link already exists for these two models, and in the opposite direction than you specified:\n";
        $string .= "to_model: ".$reverse_bridge->to_model." (this model)\n";
        $string .= "from_model: ".$reverse_bridge->from_model." (the model you are trying to set as a 'to' model for this one)\n";
        $string .= "role: ".$reverse_bridge->role;
        $self->error_message($string);
        die;
    }
    my $bridge = Genome::Model::Link->get(from_model_id => $from_id, to_model_id => $to_id);
    if ($bridge){
        my $string =  "A model link already exists for these two models:\n";
        $string .= "to_model: ".$bridge->to_model." (the model you are trying to set as a 'to' model for this one)\n";
        $string .= "from_model: ".$bridge->from_model." (this model)\n";
        $string .= "role: ".$bridge->role;
        $self->error_message($string);
        die;
    }
    $bridge = Genome::Model::Link->create(from_model_id => $from_id, to_model_id => $to_id, role => $role);
    return $bridge;
}

sub add_from_model{
    my $self = shift;
    $DB::single = 1;
    my (%params) = @_;
    my $model = delete $params{from_model};
    my $role = delete $params{role};
    $role||='member';
   
    $self->error_message("no from_model provided!") and die unless $model;
    my $to_id = $self->id;
    my $from_id = $model->id;
    unless( $to_id and $from_id){
        $self->error_message ( "no value for this model(to_model) id: <$to_id> or from_model id: <$from_id>");
        die;
    }
    my $reverse_bridge = Genome::Model::Link->get(from_model_id => $to_id, to_model_id => $from_id);
    if ($reverse_bridge){
        my $string =  "A model link already exists for these two models, and in the opposite direction than you specified:\n";
        $string .= "to_model: ".$reverse_bridge->to_model." (the model you are trying to set as a 'from' model for this one)\n";
        $string .= "from_model: ".$reverse_bridge->from_model." (this model)\n";
        $string .= "role: ".$reverse_bridge->role;
        $self->error_message($string);
        die;
    }
    my $bridge = Genome::Model::Link->get(from_model_id => $from_id, to_model_id => $to_id);
    if ($bridge){
        my $string =  "A model link already exists for these two models:\n";
        $string .= "to_model: ".$bridge->to_model." (this model)\n";
        $string .= "from_model: ".$bridge->from_model." (the model you are trying to set as a 'from' model for this one)\n";
        $string .= "role: ".$bridge->role;
        $self->error_message($string);
        die;
    }
    $bridge = Genome::Model::Link->create(from_model_id => $from_id, to_model_id => $to_id, role => $role);
    return $bridge;
}

sub delete {
    my $self = shift;

    # This may not be the way things are working but here is the order of operations for removing db events
    # 1.) Remove all instrument data assignment entries for model
    # 2.) Set model last_complete_build_id and current_running_build_id to null
    # 3.) Remove all genome_model_build entries
    # 4.) Remove all genome_model_event entries
    # 5.) Remove the genome_model entry
    
    my @objects = $self->get_all_objects;
    for my $object (@objects) {
        unless ($object->delete) {
            $self->error_message('Failed to remove object '. $object->class .' '. $object->id);
            return;
        }
    }
    # Get the remaining events like create and assign instrument data
    for my $event ($self->events) {
        unless ($event->delete) {
            $self->error_message('Failed to remove event '. $event->class .' '. $event->id);
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

sub _build_model_filesystem_paths {
    my $self = shift;
    
    # This is actual data directory on the filesystem
    # Currently the disk is hard coded in $model->base_parent_directory
    my $model_data_dir = $self->data_directory;
    unless (Genome::Utility::FileSystem->create_directory($model_data_dir)) {
        $self->warning_message("Can't create dir: $model_data_dir");
        return;
    }

    # Fix when models are created, ensure the directory is group-writable.
    my $chmodrv = system(sprintf("chmod g+w %s", $model_data_dir));
    unless ($chmodrv == 0) {
        $self->warning_message("Error attempting to set group write permissions on model directory $model_data_dir: rv $chmodrv");
    } 

    # This is a human readable(model_name) symlink to the model_id based directory
    # This symlink is created so humans can find their data on the filesystem
    my $model_link = $self->model_link;
    if ( -l $model_link ) {
        $self->warning_message("model symlink '$model_link' already exists");
        unless (unlink $model_link) {
            $self->error_message("existing model symlink '$model_link' could not be removed");
            return;
        }
    }

    unless ( Genome::Utility::FileSystem->create_symlink($model_data_dir, $model_link) ) {
        $self->error_message("model symlink '$model_link => $model_data_dir'  could not be successfully created");
        return;
    }
    
    return 1;

}


#######################
## MODEL FOR TESTING ##
#######################

package Genome::Model::Test; {
    use Genome;

    use strict;
    use warnings;

    class Genome::Model::Test {
        is => 'Genome::Model',
        has => [
        colour =>{ via => 'processing_profile', },
        shape =>{ via => 'processing_profile', },
        ],
    };

    sub create {
        my ($class, %params) = @_;

        # Create processing profile too?
        $params{subject_type} = 'dna_resource_item_name' unless exists $params{subject_type};
        $params{subject_name} = 'a piece of dna' unless exists $params{subject_name};

        my $self = $class->SUPER::create(%params)
            or return;

        return $self;
    }
}

1;

#$HeadURL$
#$Id$
