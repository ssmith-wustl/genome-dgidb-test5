package Genome::Model::Polyscan;

use strict;
use warnings;
use Data::Dumper;

use above "Genome";

class Genome::Model::Polyscan{
    is => 'Genome::Model::Sanger',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;
}

sub _type{
    my $self = shift;
    return "polyscan";
}

sub _archiveable_file_names{
    my $self = shift;
    my @super = $self->SUPER::_archiveable_file_names;
    #TODO any other files?
    my @final = (@super,);  #extra_files
    return @final;
}

#TODO implementation specific processing methods
