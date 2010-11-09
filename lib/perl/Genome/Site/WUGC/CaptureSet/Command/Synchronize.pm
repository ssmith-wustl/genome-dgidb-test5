package Genome::Site::WUGC::CaptureSet::Command::Synchronize;

use strict;
use warnings;

use Genome;

class Genome::Site::WUGC::CaptureSet::Command::Synchronize {
    is => 'Genome::Command::Base',
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

    $self->backfill_feature_lists_for_capture_sets();
    $self->backfill_capture_sets_for_feature_lists();

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

    my $found = 0;

    my $lims_cs = $capture_set->_capture_set;

    unless($lims_cs->file_storage_id) {
        my $temp_bed_file = Genome::Utility::FileSystem->create_temp_file_path;
        my $ok = $self->load_bed_file($capture_set, $temp_bed_file);

        if($ok) {
            #is true bed, since that's what this script outputs
            my $fl = $self->create_feature_list(
                name => $capture_set->name,
                file_path => $temp_bed_file,
                format => 'true-BED',
            );
            $found = $fl;
        } else  {
            my $name = $capture_set->name;
            $self->error_message("Capture set $name has neither associated file storage nor support from capture_file_dumper.");
            return;
        }
    }

    $found ||= $self->guess_agilent($capture_set);
    $found ||= $self->guess_nimblegen($capture_set);
    $found ||= $self->guess_true_bed($capture_set);

    #Can't automatically deduce format--will require manual intervention before pipeline use!
    $found ||= $self->create_unknown($capture_set);

    return $found;
}

sub create_feature_list {
    my $self = shift;
    my @params = @_;

    my $fl_command = Genome::FeatureList::Command::Create->create(@params);
    my $fl = $fl_command->execute;
    unless($fl) {
        my %params = @params;
        $self->error_message("Failed to create a feature-list for name: " . $params{name});
        die($self->error_message);
    }

    return $fl;
}


sub guess_nimblegen {
    my $self = shift;
    my $capture_set = shift;

    my $bed_file_content = $capture_set->_capture_set->get_file_storage->content;

    unless($bed_file_content) {
        $self->error_message('Could not find BED file for capture set ' . $capture_set->name . '.');
        die($self->error_message);
    }

    my $temp_bed_file = Genome::Utility::FileSystem->create_temp_file_path;
    Genome::Utility::FileSystem->write_file($temp_bed_file, $bed_file_content);

    my %params = (
        name => $capture_set->name,
        source => 'nimblegen',
        file_path => $temp_bed_file
    );

    if($bed_file_content =~ /track name=/ims) {
        my $fl = $self->create_feature_list(
            %params,
            format => 'multi-tracked 1-based',
        );
        return $fl;
    }

    if($capture_set->name =~ /nimblegen/i) {
        my $fl = $self->create_feature_list(
            %params,
            format => '1-based',
        );
        return $fl;
    }

    return;
}

sub guess_agilent {
    my $self = shift;
    my $capture_set = shift;

    return unless $capture_set->name =~ /agilent/i;

    my $bed_file_content = $capture_set->_capture_set->get_file_storage->content;

    unless($bed_file_content) {
        $self->error_message('Could not find BED file for capture set ' . $capture_set->name . '.');
        die($self->error_message);
    }

    my $temp_bed_file = Genome::Utility::FileSystem->create_temp_file_path;
    Genome::Utility::FileSystem->write_file($temp_bed_file, $bed_file_content);

    my %params = (
        name => $capture_set->name,
        source => 'agilent',
        file_path => $temp_bed_file,
        format => '1-based',
    );

    my $fl = $self->create_feature_list(
        %params,
    );

    return $fl;
}

sub guess_true_bed {
    my $self = shift;
    my $capture_set = shift;

    my $bed_file_content = $capture_set->_capture_set->get_file_storage->content;

    unless($bed_file_content) {
        $self->error_message('Could not find BED file for capture set ' . $capture_set->name . '.');
        die($self->error_message);
    }

    my $temp_bed_file = Genome::Utility::FileSystem->create_temp_file_path;
    Genome::Utility::FileSystem->write_file($temp_bed_file, $bed_file_content);

    my %params = (
        name => $capture_set->name,
        format => 'true-BED',
        file_path => $temp_bed_file,
    );

    my @lines = split("\n",$bed_file_content);
    for my $line (@lines) {
        my @fields = split("\t", $line);
        if($fields[1] == 0) {
            my $fl = $self->create_feature_list(
                %params,
            );
            return $fl;
        }
    }

    return;
}

sub create_unknown {
    my $self = shift;
    my $capture_set = shift;

    my $bed_file_content = $capture_set->_capture_set->get_file_storage->content;

    unless($bed_file_content) {
        $self->error_message('Could not find BED file for capture set ' . $capture_set->name . '.');
        die($self->error_message);
    }

    my $temp_bed_file = Genome::Utility::FileSystem->create_temp_file_path;
    Genome::Utility::FileSystem->write_file($temp_bed_file, $bed_file_content);

    my %params = (
        name => $capture_set->name,
        format => 'unknown',
        file_path => $temp_bed_file,
    );

    my $fl = $self->create_feature_list(
        %params,
    );
    return $fl;
}

sub load_bed_file {
    my $self = shift;
    my $capture_set = shift;
    my $temp_file_path = shift;

    my @barcodes = $capture_set->barcodes;
    unless(scalar @barcodes) {
        warn "no barcodes";
        return;
    }

    my $cmd = '/gsc/scripts/bin/capture_file_dumper --barcode='. $barcodes[0] .' --output-type=region-bed --output-file='. $temp_file_path;

    eval {
        Genome::Utility::FileSystem->shellcmd(
            cmd => $cmd,
            output_files => [$temp_file_path],
        );
    };

    if($@) {
        $self->error_message('Could not dump BED file: ' . $@);
        return;
    }

    return 1;
}

1;
