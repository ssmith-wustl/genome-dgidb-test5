package Genome::Model::Build::Assembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Assembly {
    is => 'Genome::Model::Build',
    has => [ ],
 };

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    my $model = $self->model;

    my @instrument_data = $model->instrument_data;

    unless (scalar(@instrument_data) && ref($instrument_data[0])  &&  $instrument_data[0]->isa('Genome::InstrumentData::454')) {
        $self->error_message('InstrumentData has not been added to model: '. $model->name);
        $self->error_message("The following command will add all available InstrumentData:\ngenome model add-reads --model-id=".
        $model->id .' --all');
        $self->delete;
        return;
    }
    return $self;
}

sub assembly_directory {
    my $self = shift;
    return $self->data_directory . '/assembly';
}

sub sff_directory {
    my $self = shift;
    return $self->data_directory . '/sff';
}

sub assembly_project_xml_file {
    my $self = shift;
    return $self->assembly_directory .'/454AssemblyProject.xml'
}

1;

