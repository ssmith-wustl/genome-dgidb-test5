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
            for my $e (@{$rf->{enumerated_types}}) {
                my $enum = Genome::Nomenclature::Field::EnumValue->create(nomenclature_field=>$f, value=>$e);
            }
        } 
    }
    print Data::Dumper::Dumper($nom);
    return $nom;
}


1;
