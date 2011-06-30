package Genome::Site::WUGC::Synchronize::Expunge;

use strict;
use warnings;
use Genome;
use Mail::Sender;

class Genome::Site::WUGC::Synchronize::Expunge {
    is => 'Genome::Command::Base',
    has => [
        report => {
            is => 'Hashref',
            is_input => 1,
            is_optional => 0,
            doc => 'Hashref containing objects of interest from Genome::Site::WUGC::Synchronze::UpdateApipeClasses',
        },
    ],
};

sub execute {
    my $self = shift;
    my %report = %{$self->report};
    my %expunge_notifications;

    for my $class (keys %report){
        next unless $class =~ m/Genome::InstrumentData/; #only remove instrument data for now
        next if $class eq 'Genome::InstrumentData::Imported'; #imported instrument data doesn't come from LIMS, so skip it
        my @ids = @{$report{$class}->{missing}} if $report{$class}->{missing};
        my @deleted;
        for my $id (@ids){
            my ($successfully_deleted, %expunge_info) = $self->_remove_expunged_object($class, $id);
            push @deleted, $successfully_deleted;
            $self->_merge_expunge_notifications(\%expunge_notifications, \%expunge_info);
        }
        $report{$class}->{deleted} = \@deleted;
    }

    $self->_notify_expunged_objects_owners(%expunge_notifications);

    return 1;
}

sub _remove_expunged_object {
    my $self = shift;
    my $class = shift;
    my $id = shift;
    my %affected_users;

    my $object = $class->get($id);
    if ($class =~ m/Genome::InstrumentData/){
        #TODO: this should nuke alignment results for instrument data
        %affected_users = $object->_expunge_assignments
    }

    $object->delete;

    return ($id, %affected_users);
}

sub _merge_expunge_notifications {
    my $self = shift;
    my $master_notifications = shift;
    my $new_notifications = shift;

    for my $user_name (keys %$new_notifications){
        my %tmp;
        if($master_notifications->{$user_name}){
            %tmp =  (%{$new_notifications->{$user_name}}, %{$master_notifications->{$user_name}});
        }else{
            %tmp = (%{$new_notifications->{$user_name}});
        }
        $master_notifications->{$user_name} = \%tmp;
    }

    return %$master_notifications;
}

sub _notify_expunged_objects_owners{
    my $self = shift;
    my %expunge_notifications = @_;
    
    for my $user_name (keys %expunge_notifications){
        my $msg = $self->_generate_expunged_objects_message_text(%{$expunge_notifications{$user_name}});
        my $instrument_data_id_string = join(', ', keys %{$expunge_notifications{$user_name}});
        my $sender = Mail::Sender->new({
                smtp    => 'gscsmtp.wustl.edu',
                from    => 'Apipe <apipe-builder@genome.wustl.edu>'
                });
        if($user_name eq 'apipe-builder'){
            $sender->MailMsg( { 
                    to      => 'Analysis Pipeline <apipebulk@genome.wustl.edu>, ' . "$user_name".'@genome.wustl.edu', 
                    cc      => 'Jim Weible <jweible@genome.wustl.edu>, Thomas Mooney <tmooney@genome.wustl.edu>', 
                    subject => "Expunged Instrument Data: $instrument_data_id_string", 
                    msg     => "LIMS has expunged instrument data used in some of your models.  Existing builds using this data will be abandoned and the model will be rebuilt.  Please contact APipe if you have any questions regarding this process.\n\n$msg", 
                    });
        }
    }
}


sub _generate_expunged_objects_message_text{
    my $self = shift;
    my %expunge_notifications_for_user = @_;
    
    my $output = "";
    for my $instrument_data_id (keys %expunge_notifications_for_user){
        $output .= "Instrument Data: $instrument_data_id\n";
        $output .= join("", map("\tModel Id: $_\n", @{$expunge_notifications_for_user{$instrument_data_id}})); 
        $output .= "\n";
    }
    return $output;
}
1;
