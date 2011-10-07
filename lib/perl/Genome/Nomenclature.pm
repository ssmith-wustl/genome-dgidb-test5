package Genome::Nomenclature;

use strict;
use warnings;

use Command::Dispatch::Shell;
use Genome;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use JSON::XS;

class Genome::Nomenclature {
    table_name => 'GENOME_NOMENCLATURE',
    id_generator => '-uuid',
    id_by => {
        'id' => {is=>'Text', len=>64}
    },
    has => [
        name => {
            is=>'Text', 
            len=>255, 
            doc => 'Nomenclature name'
        },
        fields => {
            is => 'Genome::Nomenclature::Field',
            is_many => 1,
            reverse_as => 'nomenclature'
        }
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Nomenclatures'
};

sub create {
    my $class = shift;
    my %p = @_;

    if (exists $p{json}) {
        return $class->create_from_json($p{json});    
    } 

    $class->SUPER::create(@_);    
}

sub create_from_json {
    my $class = shift;
    my $json = shift;

    my $nomenclature_raw = decode_json($json);

    my $nom = $class->create(name => $nomenclature_raw->{name});    

    for my $rf (@{$nomenclature_raw->{fields}}) {
        my $f = Genome::Nomenclature::Field->create(name=>$rf->{name}, type=>$rf->{type}, nomenclature=>$nom);
        if ($rf->{type} eq 'enumerated') {
            for my $e (@{$rf->{enumerated_values}}) {
                my $enum = Genome::Nomenclature::Field::EnumValue->create(nomenclature_field=>$f, value=>$e);
            }
        } 
    }
    return $nom;
}

sub json {
    my $self = shift;

    my $json = shift;
    if (!$json) {
        die "no JSON passed in";
    }
    my $nomenclature_raw = decode_json($json);
    if (!$nomenclature_raw) {
        die "no decodable JSON";
    } 

    #die Data::Dumper::Dumper($self);

    if ($nomenclature_raw->{name} ne $self->name) {
        $self->name($nomenclature_raw->{name});
    }
    my %field_ids = map {$_->id, 1} Genome::Nomenclature::Field->get(nomenclature=>$self);

    for my $rf (@{$nomenclature_raw->{fields}}) {
        my $field_record;
        if ($rf->{id}) {
            $field_record = Genome::Nomenclature::Field->get($rf->{id});
        }

        my %enum_records;
        warn $field_record->type;
        if ($field_record->type eq 'enumerated') {
            %enum_records = map {$_,1} Genome::Nomenclature::Field::EnumValue->get(nomenclature_field=>$field_record);
           
            my @record_ids = @{$rf->{enumerated_value_ids}}; 
            my @record_values = @{$rf->{enumerated_values}}; 
            for my $i (0...$#record_ids) {
                delete $enum_records{$record_ids[$i]};
                my $e = Genome::Nomenclature::Field::EnumValue->get($record_ids[$i]);
                warn sprintf("Updating %s to %s", $e->value, $record_values[$i]);
                $e->value($record_values[$i]);
            }
        }

        if ($field_record) {
            $field_record->name($rf->{name});
            if ($rf->{type} eq 'enumerated' && $field_record->{type} ne 'enumerated') {
                for my $e (@{$rf->{enumerated_values}}) {
                    my $enum = Genome::Nomenclature::Field::EnumValue->create(nomenclature_field=>$field_record, value=>$e);
                }
            }
            $field_record->type($rf->{type})
        } 
    }

    return $self;
}

sub __display_name__ {
    shift->name;

}


1;
