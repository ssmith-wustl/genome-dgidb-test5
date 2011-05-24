package Genome::Site::WUGC::SynchronizeSolexaInstrumentData;

use strict;
use warnings;
use Genome;

class Genome::Site::WUGC::SynchronizeSolexaInstrumentData {
    is => 'Genome::Command::Base',
    has => [
        instrument_data => { 
            # is => 'Genome::InstrumentData::Solexa', 
            is => 'Text', 
            doc => 'The instrument data to update',
            shell_args_position => 1,
            is_many => 1,
            is_input => 1,
        },
    ],
    doc => 'This command will update one or more Genome::InstrumentData using the data in the LIMS system',
};

sub execute {
   my $self = shift; 
   
   my @instrument_data_ids = $self->instrument_data(); 
   for my $instrument_data_id(@instrument_data_ids){
       my $new_object = Genome::InstrumentData::Solexa->get($instrument_data_id);
       unless ($new_object){
           $self->error_message("Could not find Genome::InstrumentData::Solexa with id: " . $instrument_data_id);
           next;
       }
       my $old_object = Genome::Site::WUGC::InstrumentData::Solexa->get($instrument_data_id);
       unless ($old_object){
           $self->error_message("Could not find Genome::Site::WUGC::InstrumentData::Solexa with id: " . $instrument_data_id);
           next;
       }
       $self->_update_genome_instrumentdata_solexa($old_object, $new_object, 'Genome::InstrumentData::Solexa');
   }

   return 1;
}

sub _update_genome_instrumentdata_solexa {
    my ($self, $original_object, $new_object, $new_object_class) = @_;
    
    my ($direct_properties, $indirect_properties) = $self->_get_direct_and_indirect_properties_for_object(
        $original_object,
        $new_object_class, 
        qw/ sample_name sample_id subclass_name/
    );

    $DB::single =1;
    for my $property (keys %$direct_properties){
        $new_object->$property($original_object->{$property});
    }

    for my $property (keys %$indirect_properties){
        $new_object->$property($indirect_properties->{$property});
    }

    return 1;
}

sub _get_direct_and_indirect_properties_for_object {
    my ($self, $original_object, $class, @ignore) = @_;
    my %direct_properties;
    my %indirect_properties;

    my @properties = $class->__meta__->_legacy_properties;
    for my $property (@properties) {
        my $property_name = $property->property_name;
        my $value = $original_object->{$property_name};
        next if @ignore and grep { $property_name eq $_ } @ignore;
        next unless defined $value;

        my $via = $property->via;
        if (defined $via and $via eq 'attributes') {
            $indirect_properties{$property_name} = $value;
        }
        else {
            $direct_properties{$property_name} = $value;
        }
    }

    return (\%direct_properties, \%indirect_properties);
}

1;
