package Genome::Site::WUGC::SynchronizeTaxon;

use strict;
use warnings;
use Genome;

class Genome::Site::WUGC::SynchronizeTaxon {
    is => 'Genome::Command::Base',
    has => [
        taxon => { 
            # is => 'Genome::Taxon', 
            is => 'Text', 
            doc => 'The taxon to update',
            shell_args_position => 1,
            is_many => 1,
            is_input => 1,
        },
    ],
    doc => 'This command will update one or more Genome::Taxon using the data in the LIMS system',
};

sub execute {
   my $self = shift; 

   my @taxon_ids = $self->taxon(); 
   for my $taxon_id(@taxon_ids){
       my $new_object = Genome::Taxon->get($taxon_id);
       unless ($new_object){
           $self->error_message("Could not find Genome::Taxon with id: " . $taxon_id);
           next;
       }
       my $old_object = Genome::Site::WUGC::Taxon->get($taxon_id);
       unless ($old_object){
           $self->error_message("Could not find Genome::Site::WUGC::Taxon with id: " . $taxon_id);
           next;
       }
       $self->_update_genome_taxon($old_object, $new_object, 'Genome::Taxon');
   }

   return 1;
}

sub _update_genome_taxon {
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

    my @properties = $class->__meta__->properties;
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
