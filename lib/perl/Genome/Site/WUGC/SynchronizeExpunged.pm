package Genome::Site::WUGC::SynchronizeExpunged;

use strict;
use warnings;
use Genome;

class Genome::Site::WUGC::SynchronizeExpunged {
    is => 'Genome::Command::Base',
    has => [
        report => {
            is => 'Hashref',
            is_input => 1,
            is_optional => 0,
            doc => 'The output from a Genome::Site::WUGC::Synchronze', #TODO: write something better than this
        }
    ],
};

sub execute {
    my $self = shift;
    my %report = %{$self->report};

    for my $class (keys %report){
        next unless $class =~ m/Genome::InstrumentData/; #only remove instrument data for now
        next if $class eq 'Genome::InstrumentData::Imported'; #imported instrument data doesn't come from LIMS, so skip it
        my @ids = @{$report{$class}->{missing}};
        my @deleted;
        for my $id (@ids){
            my $successfully_deleted = $self->_remove_expunged_object($class, $id);
            push @deleted, $successfully_deleted;
        }
        $report{$class}->{deleted} = \@deleted;
    }
}

sub _remove_expunged_object {
    my $self = shift;
    my $class = shift;
    my $id = shift;

    #TODO: this should nuke alignment results for instrument data

    my $object = $class->get($id);
    $object->delete;

    return $id;
}

1;
