package Genome::Model::Build;

use strict;
use warnings;

use Genome;
use YAML;

class Genome::Model::Build {
    type_name => 'genome model build',
    table_name => 'GENOME_MODEL_BUILD',
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
              build_id => { is => 'NUMBER', len => 10, },
          ],
    has => [
            model_id => { is => 'NUMBER', len => 10, constraint_name => 'GMB_GMM_FK' },
            data_directory => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
            model => { is => 'Genome::Model', id_by => 'model_id' },
        ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self) {
        return;
    }
    unless ($self->data_directory) {
        $self->data_directory($self->resolve_data_directory);
    }
    return $self;
}

sub events {
    my $self = shift;

    my @events = Genome::Model::Event->get(
                                           model_id => $self->model_id,
                                           build_id => $self->build_id,
                                       );
    return @events;
}

sub build_events {
    my $self = shift;

    my @build_events = Genome::Model::Command::Build->get(
                                                    model_id => $self->model_id,
                                                    build_id => $self->build_id,
                                                );
    return @build_events;
}

sub build_event {
    my $self = shift;
    my @build_events = $self->build_events;
    if (scalar(@build_events) > 1) {
        my $error_message = 'Found '. scalar(@build_events) .' build events for model id '.
            $self->model_id .' and build id '. $self->build_id ."\n";
        for (@build_events) {
            $error_message .= "\t". $_->desc .' '. $_->event_status ."\n";
        }
        die($error_message);
    }
    return $build_events[0];
}

sub resolve_data_directory {
    my $self = shift;
    my $model = $self->model;
    return $model->data_directory . '/build' . $self->build_id;
}

sub available_reports {
    my $self = shift;
    my $report_dir = $self->resolve_data_directory . '/reports/';
    my %report_file_hash;
    my @report_subdirs = glob("$report_dir/*");
    my @reports;
    for my $subdir (@report_subdirs) {
        #we may be able to do away with touching generating class and just try to find reports that match this subdir name? not sure
        my ($report_name) = ($subdir =~ /\/+reports\/+(.*)\/*/);
        push @reports, Genome::Model::Report->create(model_id => $self->model->genome_model_id, name => $report_name);
    }
    return \@reports; 
}


#< SUBCLASSING >#
#
# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _resolve_subclass_name {
    my $class = shift;

    my $type_name;
	if ( ref($_[0]) and $_[0]->isa(__PACKAGE__) ) {
		$type_name = $_[0]->model->type_name;
	}
    else {
        my %params = @_;
        my $model_id = $params{model_id};
        my $model = Genome::Model->get($model_id);
        unless ($model) {
            return undef;
        }
        $type_name = $model->type_name;
    }

    unless ( $type_name ) {
        my $rule = $class->get_rule_for_params(@_);
        $type_name = $rule->specified_value_for_property_name('type_name');
    }

    if (defined $type_name ) {
        my $subclass_name = $class->_resolve_subclass_name_for_type_name($type_name);
        my $sub_classification_method_name = $class->get_class_object->sub_classification_method_name;
        if ( $sub_classification_method_name ) {
            if ( $subclass_name->can($sub_classification_method_name)
                 eq $class->can($sub_classification_method_name) ) {
                return $subclass_name;
            } else {
                return $subclass_name->$sub_classification_method_name(@_);
            }
        } else {
            return $subclass_name;
        }
    } else {
        return undef;
    }
}

sub _resolve_subclass_name_for_type_name {
    my ($class,$type_name) = @_;
    my @type_parts = split(' ',$type_name);

    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);

    my $class_name = join('::', 'Genome::Model::Build' , $subclass);
    return $class_name;

}

sub _resolve_type_name_for_class {
    my $class = shift;

    my ($subclass) = $class =~ /^Genome::Model::Build::([\w\d]+)$/;
    return unless $subclass;

    return lc join(" ", ($subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx));

    my @words = $subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx;
    return lc(join(" ", @words));
}

sub get_all_objects {
    my $self = shift;
    return;
}

sub yaml_string {
    my $self = shift;
    my $string = YAML::Dump($self);
    for my $object ($self->get_all_objects) {
        $string .= YAML::Dump($object);
    }
    return $string;
}

1;
