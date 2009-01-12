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
    $self->model->current_running_build_id($self->build_id);
    return $self;
}

sub builder {
    my $self = shift;

    my @builders = Genome::Model::Command::Build->get(
                                                      model_id => $self->model_id,
                                                      build_id => $self->build_id,
                                                  );
    unless (scalar(@builders)) {
        return;
    }
    unless (scalar(@builders)) {
        $self->error_message('Found '. scalar(@builders) .' build events(builders) for model '. $self->model_id .' and build '. $self->build_id);
        return;
    }
    return $builders[0];
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

    return ( defined $type_name ) 
    ? $class->_resolve_subclass_name_for_type_name($type_name)
    : undef;
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
