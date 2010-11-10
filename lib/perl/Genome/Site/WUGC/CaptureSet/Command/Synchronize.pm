package Genome::Site::WUGC::CaptureSet::Command::Synchronize;

use strict;
use warnings;

use Genome;

class Genome::Site::WUGC::CaptureSet::Command::Synchronize {
    is => 'Genome::Command::Base',
    has => [
        direction => {
            is => 'Text',
            valid_values => ['forward', 'reverse', 'both'],
            default_value => 'forward',
            doc => 'Which way to synchronize.  Forward imports feature-lists for capture-sets. Reverse adds back capture-sets for any otherwise created feature-lists'
        },
        report => {
            is => 'Boolean',
            default_value => 1,
            doc => 'Include a report of those feature-lists missing critical information for processing',
        },
        _forward => {
            calculate_from => ['direction'],
            calculate => q{ return $direction eq 'forward' or $direction eq 'both' },
        },
        _reverse => {
            calculate_from => ['direction'],
            calculate => q{ return $direction eq 'reverse' or $direction eq 'both' },
        },
    ],
};

sub help_brief {
    "Create a Genome::FeatureList for any capture-set without one",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
EOS
}

sub help_detail {                           
    return <<EOS 
Examines the list of capture-sets and looks for any without a similarly-named feature-list and imports them.
EOS
}

sub execute {
    my $self = shift;

    $self->backfill_feature_lists_for_capture_sets()    if $self->_forward;
    $self->backfill_capture_sets_for_feature_lists()    if $self->_reverse;
    $self->report_unusable_feature_lists()              if $self->report;

    return 1;
}

sub backfill_capture_sets_for_feature_lists {
    my $self = shift;

    my @capture_sets = Genome::Site::WUGC::CaptureSet->get();  #just preload these--we'll "get" them individually by name later
    my $feature_list_iterator = Genome::FeatureList->create_iterator('-order_by' => ['name']);

    unless($feature_list_iterator) {
        $self->error_message('Failed to create iterator for feature lists.');
        die $self->error_message;
    }

    while(my $feature_list = $feature_list_iterator->next) {
        my $existing_capture_set = Genome::Site::WUGC::CaptureSet->get(name => $feature_list->name);

        if($existing_capture_set) {
            #Do nothing; it's already here!
        } else {
            $self->create_capture_set_for_feature_list($feature_list);
        }
    }

    return 1;
}

sub create_capture_set_for_feature_list {
    my $self = shift;
    my $feature_list = shift;

    eval {
        my $cmd = '/gsc/scripts/bin/execute_create_capture_container --bed-file='. $feature_list->file_path .' --setup-name=\''. $feature_list->name .'\'';
        Genome::Utility::FileSystem->shellcmd(
            cmd => $cmd,
        );
    };

    if($@) {
        $self->error_message('Failed to create capture container for ' . $feature_list->name);
        die $self->error_message;
    }

    return 1;
}

sub backfill_feature_lists_for_capture_sets {
    my $self = shift;
    
    my $capture_set_iterator = Genome::Site::WUGC::CaptureSet->create_iterator('-order_by' => ['name']);
    my @feature_lists = Genome::FeatureList->get(); #just preload these--we'll "get" them individually by name later

    unless($capture_set_iterator) {
        $self->error_message('Failed to create iterator for capture sets.');
        die $self->error_message;
    }

    while(my $capture_set = $capture_set_iterator->next) {
        my $existing_feature_list = Genome::FeatureList->get(name => $capture_set->name);

        if($existing_feature_list) {
            #Do nothing; it's already here!
        } else {
            $self->create_feature_list_for_capture_set($capture_set);
        }
    }

    return 1;
}

sub create_feature_list_for_capture_set {
    my $self = shift;
    my $capture_set = shift;

    unless($capture_set->file_storage_id) {
        $self->warning_message('capture set ' . $capture_set->id . ' has no file_storage_id and thus cannot be synchronized.');
        return;
    }

    my @params;

    my $meta = Genome::FeatureList::Command::Create->__meta__;
    my @property_meta = $meta->all_property_metas;

    my @param_names = map { $_->property_name } grep { defined $_->{'is_input'} && $_->{'is_input'} } @property_meta;
    for my $param_name (@param_names) {
        push @params,
            $param_name => $capture_set->$param_name;
    }

    my $fl_command = Genome::FeatureList::Command::Create->create(@params);
    my $fl = $fl_command->execute;
    unless($fl) {
        my %params = @params;
        $self->error_message("Failed to create a feature-list for name: " . $params{name});
        die($self->error_message);
    }

    return $fl;
}

#Display a list of all those feature-lists that cannot be used in pipelines because they are missing important values.
sub report_unusable_feature_lists {
    my $self = shift;

    $self->status_message('The following feature-lists have an unknown format.');
    my $unknown_format_command = Genome::FeatureList::Command::List->create(
        show => 'name,id',
        filter => 'format=unknown',
    );
    unless($unknown_format_command->execute()) {
        $self->error_message('Error listing feature-lists with unknown format.');
    }

    $self->status_message('The following feature-lists have no specified reference.');
    my $unknown_reference_command = Genome::FeatureList::Command::List->create(
        show => 'name,id',
        filter => "reference_id=''",
    );
    unless($unknown_reference_command->execute()) {
        $self->error_message('Error listing feature-lists with no specified reference.');
    }

    return 1;
}

1;
