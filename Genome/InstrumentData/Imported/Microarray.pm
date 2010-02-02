package Genome::InstrumentData::Imported::Microarray;

use strict;
use warnings;
 
use Genome;
use File::stat;

my $default_size_return = 250000000;


class Genome::InstrumentData::Imported::Microarray{
    is  => 'Genome::InstrumentData::Imported',
    doc => 'Utilities for importing microarray data',
};

sub calculate_microarray_estimated_kb_usage {
    my $self = shift;
    if (-s $self->original_data_path) {
        my $stat = stat($self->original_data_path);
        return int($stat->size/1000 + 100);   #use kb as unit
    }
    else {
        return $default_size_return;
    }

}

sub create {
    my $class = shift;
     
    my %params = @_;
    my $user   = getpwuid($<);
    my $date   = UR::Time->now;
     
    $params{import_date} = $date;
    $params{user_name}   = $user;
     
    my $self = $class->SUPER::create(%params);
     
    return $self;
}

