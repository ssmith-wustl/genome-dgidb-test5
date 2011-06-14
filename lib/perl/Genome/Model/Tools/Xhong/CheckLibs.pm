package Genome::Model::Tools::Xhong::CheckLibs;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Xhong::CheckLibs {
    is => 'Command',
    has => [
    group => { 
        type => 'String',
        is_optional => 1,
        doc => "model group to report outliers for",
    },
    builds => {
        type => 'String',
        is_optional => 1,
        doc => "builds to report outliers for",
    },
    above_cutoff => {
        type => 'float',
        is_optional => 1,
        default => 0.2,
    },
    below_cutoff => {
        type => 'float',
        is_optional => 1,
        default => 0.3,
    },

    ]
};


sub execute {
    my $self=shift;
    $DB::single = 1;
    my @builds;
    if($self->builds) {
        @builds = map { Genome::Model::Build->get($_); }  split /\s+/, $self->builds;
    }
    elsif($self->group) {
        my $group = Genome::ModelGroup->get(name => $self->group);
        unless($group) {
            $self->error_message("Unable to find a model group named " . $self->group);
            return;
        }
        for my $model ($group->models) {
            my $build = $model->last_complete_build;
            unless($build) {
                $self->error_message("No complete build for model " . $model->id);
            }
            else {
                push @builds, $build;
            }
        }
    }
    else {
        $self->error_message("You must provide either build id(s) or a model group name to run this script");
        return;
    }

    print "Lanes indicating bad libraries\n";
    print join("\t",qw(Common_Name Name Library Insert_Size Var_Below Var_Above)), "\n";
    foreach my $build (@builds) {
        my $model = $build->model;
        unless(defined($model)) {
            $self->error_message("Somehow this build does not have a model");
            return;
        }

        #calculate common name like AML11
        my $common_name = $model->subject->source_common_name;

        #this should tell us about whether it's tumor or normal
        my $type = $model->subject->common_name;

        printf STDERR "Grabbing information for model %s (build %s)\n", $model->name, $build->build_id;       
        #Grab all alignment events so we can filter out ones that are still running or are abandoned
        # get all align events for the current running build
        my @align_events = Genome::Model::Event->get(event_type => 
            {operator => 'like', value => '%align-reads%'},
            build_id => $build,
            model_id => $model->id,
        );
        printf STDERR "%d lanes in build\n", scalar(@align_events);
=cut
        #now just get the Succeeded events to pass along for further processing
        # THIS MAY NOT INCLUDE ANY EVENTS
        my @events = Genome::Model::Event->get(event_type => 
            {operator => 'like', value => '%align-reads%'},
            build_id => $build,
            event_status => 'Succeeded',
            model_id => $model->id,

        );
        # if it does not include any succeeded events - die
        unless (@events) {
            $self->error_message("No alignments have Succeeded on the build. Skipping this model.");
            next;
        }
=cut
        my @inputs = map { $_->instrument_data_input } @align_events;

        my %bad_lanes;
        my %total_lanes;
        
        for my $input (@inputs) { 
            my $instrument_data = $input->value;
            my $library = $instrument_data->library_name;
            unless(defined($library)) {
                $self->error_message("No library defined for ".$instrument_data->id);
                next;
            }

            my $ispe = ($instrument_data->is_paired_end && ! defined($input->filter_desc));
            next unless $ispe;

            $total_lanes{$library}++;

            my $instrument_data_id = $instrument_data->id;
            my $lane_name = $instrument_data->short_name."_".$instrument_data->subset_name;
            my $median_insert_size = $instrument_data->median_insert_size;
            my $sd_above_insert_size = $instrument_data->sd_above_insert_size;
            my $sd_below_insert_size = $instrument_data->sd_below_insert_size;
            if(!$median_insert_size || ($sd_below_insert_size/$median_insert_size) > 0.3 || ($sd_above_insert_size/$median_insert_size) > 0.2) {
                printf "%s\t%s\t%s\t%0.2f\t%0.2f\t%0.2f\n",$lane_name,$library,$median_insert_size, $median_insert_size ? $sd_below_insert_size/$median_insert_size : undef, $median_insert_size ? $sd_above_insert_size/$median_insert_size : undef;
                $bad_lanes{$library}++;
            }
        }
        foreach my $lib (keys %total_lanes) {
            printf "%0.2f%% lanes bad for %s %s library %s\n",$bad_lanes{$lib}/$total_lanes{$lib}*100,$lib;
        }
    }
    return 1;

}


1;

sub help_brief {
    "Prints out various paired end library metrics regarding mapping and paired end-ness"
}

sub help_detail {
    <<'HELP';
This script uses the Genome Model API to grab out all alignment events for a model and grab net metrics for the entire library. It ignores runs which have not succeeded in their alignment (silently). 
HELP
}
