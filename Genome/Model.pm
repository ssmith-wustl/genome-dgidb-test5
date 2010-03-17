
# review jlolofie gsanders
# 2. remove stuff that is not generic to models (goldsnp path... should be in model/ReferenceAlignment? )
#
#    (need to think about / work on "star" models)
# 4.  Genome::Config calls... 4 methods below with : TODO: remove these since they're not supposed to vary on a per-model basis.... 
#    what needs to be done with these?


package Genome::Model;

use strict;
use warnings;

use Genome;

use Regexp::Common;
use File::Path;
use Cwd;
use File::Basename;
use IO::File;
use Sort::Naturally;
use YAML;
use Archive::Tar;

class Genome::Model {
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
            valid_values => ["species_name","sample_group","flow_cell_id","genomic_dna","library_name","sample_name","dna_resource_item_name"] 
        },
        auto_assign_inst_data   => { is => 'Number', len => 4, is_optional => 1 },
        auto_build_alignments   => { is => 'Number', len => 4, is_optional => 1 },
        subject                 => { 
            calculate_from => [ 'subject_id', 'subject_class_name' ],
            calculate => q( 
                if(defined $subject_id and defined $subject_class_name) {
                    return $subject_class_name->get($subject_id);
                } else {
                    #Old way of figuring out subject:
                    return $self->_resolve_subject
                }
            )
        },
        processing_profile      => { is => 'Genome::ProcessingProfile', id_by => 'processing_profile_id' },
        processing_profile_name => { via => 'processing_profile', to => 'name' },
        type_name               => { via => 'processing_profile' },
        events                  => { is => 'Genome::Model::Event', reverse_as => 'model', is_many => 1, 
                                    doc => 'all events which have occurred for this model' },
        subject_class_name      => { is => 'VARCHAR2', len => 500, is_optional => 1 },
        subject_id              => { is => 'NUMBER', len => 15, is_optional => 1 },
        reports                 => { via => 'last_succeeded_build' },
        reports_directory       => { via => 'last_succeeded_build' },
        is_default              => { is => 'NUMBER', len => 4, is_optional => 1 },
        model_bridges           => {
                                    is         => 'Genome::ModelGroupBridge',
                                    reverse_as => 'model',
                                    is_many    => 1
                                   },
        model_groups            => { 
                                    is      => 'Genome::ModelGroup', 
                                    via     => 'model_bridges',
                                    to      => 'model_group',
                                    is_many => 1,
                                   }
    ],
    has_optional => [
        user_name                        => { is => 'VARCHAR2', len => 64 },
        creation_date                    => { is => 'TIMESTAMP', len => 6 },
        builds                           => { is => 'Genome::Model::Build', reverse_as => 'model', is_many => 1 },
        build_statuses                   => { via => 'builds', to => 'master_event_status', is_many => 1 },
        build_ids                        => { via => 'builds', to => 'id', is_many => 1 },
        keep_n_most_recent_builds	     => { via => 'attributes', to => 'value', is_mutable => 1, 
                                              where => [ property_name => 'keep_n_most_recent_builds', entity_class_name => 'Genome::Model' ] 
                                            },
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
        comparable_normal_model          => { is => 'Genome::Model', id_by => 'comparable_normal_model_id' },
        sample_name                      => { is => 'Text', len => 255 },
        sequencing_platform              => { via => 'processing_profile' },
        last_complete_build_directory    => { calculate => q($b = $self->last_complete_build; return unless $b; return $b->data_directory) },
        last_succeeded_build_directory    => { calculate => q($b = $self->last_succeeded_build; return unless $b; return $b->data_directory) },
    ],
    has_many_optional => [
        ref_seqs                          => { is => 'Genome::Model::RefSeq', reverse_as => 'model' },
        project_assignments               => { is => 'Genome::Model::ProjectAssignment', reverse_as => 'model' },
        projects                          => { is => 'Genome::Project', via => 'project_assignments', to => 'project' },
        project_names                     => { is => 'Text', via => 'projects', to => 'name' },
        attributes                        => { is => 'Genome::MiscAttribute', reverse_as => '_model', where => [ entity_class_name => 'Genome::Model' ] },
        #< Inputs >#
        inputs => {
            is => 'Genome::Model::Input',
            reverse_as => 'model',
            doc => 'Inputs currently assigned to the model.'
        },
        # Instrument Data
        #This will be the new instrument data properties, the rest of these props will go away
        inst_data => {#instrument_data => {
            is => 'Genome::InstrumentData',
            via => 'inputs',
            is_mutable => 1,
            is_many => 1,
            where => [ name => 'instrument_data' ],
            to => 'value',
            doc => 'Instrument data currently assigned to the model.',
        },
        instrument_data => {
            via => 'instrument_data_assignments',
            to => 'instrument_data',
        },
        assigned_instrument_data          => { is => 'Genome::InstrumentData', via => 'instrument_data_assignments', to => 'instrument_data' },
        instrument_data_assignments       => { is => 'Genome::Model::InstrumentDataAssignment', reverse_as => 'model' },
        built_instrument_data             => { calculate => q( 
                                                    return 
                                                        map { $_->instrument_data } 
                                                        grep { defined $_->first_build_id } 
                                                        $self->instrument_data_assignments;
                                                ) },
        unbuilt_instrument_data           => { calculate => q( 
                                                    return 
                                                        map { $_->instrument_data } 
                                                        grep { !defined $_->first_build_id } 
                                                        $self->instrument_data_assignments;
                                                ) },
        instrument_data_assignment_events => { is => 'Genome::Model::Command::InstrumentData::Assign', reverse_as => 'model', 
            doc => 'Each case of an instrument data being assigned to the model' },
        #<>#
        from_model_links                  => { is => 'Genome::Model::Link', reverse_as => 'to_model', 
                                               doc => 'bridge table entries where this is the \"to\" model(used to retrieve models this model is \"from\")' },
        from_models                       => { is => 'Genome::Model', via => 'from_model_links', to => 'from_model', 
                                               doc => 'Genome models that contribute \"to\" this model' },
        to_model_links                    => { is => 'Genome::Model::Link', reverse_as => 'from_model', 
                                               doc => 'bridge entries where this is the \"from\" model(used to retrieve models models this model is \"to\")' },
        to_models                         => { is => 'Genome::Model', via => 'to_model_links', to => 'to_model', 
                                               doc => 'Genome models this model contributes \"to\"' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'The GENOME_MODEL table represents a particular attempt to model knowledge about a genome with a particular type of evidence, and a specific processing plan. Individual assemblies will reference the model for which they are assembling reads.',
};

# auto generate sub-classes for any valid processing profile
sub __extend_namespace__ {
    my ($self,$ext) = @_;

    my $meta = $self->SUPER::__extend_namespace__($ext);
    return $meta if $meta;
    
    my $pp_subclass_name = 'Genome::ProcessingProfile::' . $ext;
    my $pp_subclass_meta = UR::Object::Type->get($pp_subclass_name);
    if ($pp_subclass_meta) {
        my $model_subclass_name = 'Genome::Model::' . $ext;
        my $model_subclass_meta = UR::Object::Type->define(
            class_name => $model_subclass_name,
            is => 'Genome::Model',
        );
        die "Error defining $model_subclass_name for $pp_subclass_name!" unless $model_subclass_meta;
        return $model_subclass_meta;
    }
    return;
}



sub create {
    my $class = shift;
    my $params = $class->define_boolexpr(@_);
    
    # Processing profile - gotta validate here or SUPER::create will fail silently
    my $processing_profile_id = $params->value_for('processing_profile_id');
    $class->_validate_processing_profile_id($processing_profile_id)
        or return;

    my $self = $class->SUPER::create($params)
        or return;

    # Model name - use default if none given
    unless ( $self->name ) {
        $self->name(
            join(
                '.',
                Genome::Utility::Text::sanitize_string_for_filesystem($self->subject_name),
                $self->processing_profile_name
            )
        );
    }

    # Verify subjects--fills in subject_* properties
    unless ( $self->_verify_subject ) {
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
        $self->SUPER::delete;
        return;
    }

    my $processing_profile= $self->processing_profile;
    $DB::single = $DB::stopper;
    unless ($processing_profile->_initialize_model($self)) {
        $self->error_message("The processing profile failed to initialize the new model:"
            . $processing_profile->error_message);
        $self->delete;
        return;
    }

    return $self;
}

sub _validate_processing_profile_id {
    my ($class, $pp_id) = @_;

    unless ( $pp_id ) {
        $class->error_message("No processing profile id given");
        return;
    }

    unless ( $pp_id =~ m#^$RE{num}{int}$#) {
        $class->error_message("Processing profile id is not an integer");
        return;
    }

    unless ( Genome::ProcessingProfile->get(id => $pp_id) ) {
        $class->error_message("Can't get processing profile for id ($pp_id)");
        return;
    }

    return 1;
}

#This is the old way of determining subject based on type and name
#Typically this is only needed in the constructor to find the id and class_name to populate those columns
sub _resolve_subject {
    my $self = shift;
    my $subject_type = $self->subject_type;
    my $subject_name = $self->subject_name;
    
    if (not defined $subject_type or not defined $subject_name) {
        # this should not happen
        return;
    }
    elsif ($subject_type eq 'dna_resource_item_name') {
        # wtf is this?
        return GSC::DNAResourceItem->get(dna_name => $subject_name);
    }
    elsif ($subject_type eq 'genomic_dna') {
        return Genome::Sample->get(extraction_label => $subject_name, extraction_type => 'genomic dna');
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
        return Genome::Library->get(name => $subject_name);
    }
    elsif ($subject_type eq 'flow_cell_id') {
        return GSC::Equipment::Solexa::Run->get(flow_cell_id => $subject_name);
    }
    else {
        die "unknown sample type $subject_type!";
    }
}

#Eventually this can replace the subject_type property completely.
sub _subject_type_for_class_name {
    my $self = shift;
    my $subject_class_name = shift || $self->subject_class_name;
    
    return unless $subject_class_name;
    
    my %types = (
        'Genome::Sample' => 'sample_name',
        'GSC::DNAResourceItem' => 'dna_resource_item_name',
        'GSC::Equipment::Solexa::Run' => 'flow_cell_id',
        'Genome::ModelGroup' => 'sample_group',
        'Genome::PopulationGroup' => 'sample_group',
        'Genome::Individual' => 'sample_group',
        'Genome::Taxon' => 'species_name',
        'Genome::Library' => 'library_name',
        'Genome::Sample::Genomic' => 'genomic_dna',  
    );
    
    return $types{$subject_class_name};
}

#Eventually this can replace the subject_name property completely.
sub _subject_name_for_subject {
    my $self = shift;
    my $subject = shift || $self->subject;
    
    if($subject->class eq 'GSC::Equipment::Solexa::Run') {
        return $subject->flow_cell_id;
    } else {
        return $subject->name;
    }
}

sub _verify_subject {
    my $self = shift;
    
    my $subject = $self->subject;
    
    unless($subject) {
        my $null = '<NULL>';
        $self->error_message('Could not verify subject given ' . join(', ',
            'subject_id: ' . ($self->subject_id || $null),
            'subject_class_name: ' . ($self->subject_class_name || $null),
            'subject_type: ' . ($self->subject_type || $null),
            'subject_name: ' . ($self->subject_name || $null),
        ));
        return;
    }
    
    #Fill out the rest of the attributes based on what was used to create the subject
    if($self->subject_id and $self->subject_class_name) {
        $self->subject_type($self->_subject_type_for_class_name); #Backfill old way for now.
        $self->subject_name($self->_subject_name_for_subject); 
    } else {
        $self->subject_id($subject->id);
        $self->subject_class_name($subject->class);        
    }
    
    return $subject;
}

sub get_all_possible_sample_names {
    my $self = shift;

    my @sample_names;
    if ( $self->subject_class_name eq 'Genome::Taxon' ) {
        my $taxon = Genome::Taxon->get(species_name => $self->subject_name);
        @sample_names = map { $_->name } $taxon->samples;
    } elsif ($self->subject_class_name eq 'Genome::Sample'){
        @sample_names = ( $self->subject->name );
    #} elsif () {
        #TODO Possibly fill in for Genome::Individual, Genome::PopulationGroup and possibly others
    } else {
        @sample_names = ();
    }

    return @sample_names;
}

#< Instrument Data >#
sub compatible_instrument_data {
    my $self = shift;
    my %params;

    my $subject_type_class;
    if ($self->get_all_possible_sample_names)  {
        %params = (
                   sample_name => [ $self->get_all_possible_sample_names ],
               );
        $params{sequencing_platform} = $self->sequencing_platform if $self->sequencing_platform;
    } else {
        %params = (
                   $self->subject_type => $self->subject_name,
               );
        $subject_type_class = $self->instrument_data_class_name;
    }
    unless ($subject_type_class) {
        $subject_type_class = 'Genome::InstrumentData';
    }
    my @compatible_instrument_data = $subject_type_class->get(%params);
    
    if($params{sequencing_platform} and $params{sequencing_platform} eq 'solexa') {
        #FASTQs with 0 reads crash in alignment.  Don't assign them.
        @compatible_instrument_data = grep($_->total_bases_read, @compatible_instrument_data);
    }
    
    return @compatible_instrument_data;
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

# TODO: remove these since they're not supposed to vary on a per-model basis.
sub base_parent_directory {
    return Genome::Config->root_directory;
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
    my @builds = $self->builds(status => 'Succeeded');
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
        my $processing_profile = Genome::ProcessingProfile->get(id => $processing_profile_id);
        unless ( $processing_profile ) {
            $class->error_message("Can't resolve subclass because can't get processing profile for id: ".$processing_profile_id);
            return;
        }
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

sub get_all_objects {
    my $self = shift;

    my $sorter = sub { # not sure why we sort, but I put it in a anon sub for convenience
        return unless @_;
        if ( $_[0]->id =~ /^\-/) {
            return sort {$b->id cmp $a->id} @_;
        } 
        else {
            return sort {$a->id cmp $b->id} @_;
        }
    };

    return map { $sorter->( $self->$_ ) } (qw{ instrument_data_assignments inputs builds project_assignments to_model_links from_model_links });
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

    return 1;

}

1;

#$HeadURL$
#$Id$
