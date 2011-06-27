package Genome::Model::Tools::Library::GatherLibraryMetrics;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Library::GatherLibraryMetrics {
    is => 'Command',
    has => [
        model_id => { 
            type => 'String',
            is_optional => 0,
            doc => "model id of the model to gather library metrics for",
        },
        all_events => {
            type => 'Flag',
            is_optional => 1,
            default => 0,
        },
    ]
};


sub execute {
    my $self=shift;
    $DB::single = 1;
    my $model_id = $self->model_id;
    
    my $model = Genome::Model->get($model_id);
    unless(defined($model)) {
        $self->error_message("Unable to find model $model_id");
        return;
    }
    #additions to just get alignments from the latest build of this model
    my $last_complete_build = $model->last_complete_build;
    my $current_running_build = $model->current_running_build;
    my $align_count = 0;
    my @events;
    #Grab all alignment events so we can filter out ones that are still running or are abandoned
    if ($current_running_build) {
        my $current_align_count = 0; 
        # get all align events for the current running build
        my @current_running_build_align_events = Genome::Model::Event->get(event_type => 
                {operator => 'like', value => '%align-reads%'},
                build_id => $current_running_build,
                model_id => $model_id,
            );
        # check to see if any of the events have not succeeded and throw a warning
        foreach my $current_align_event (@current_running_build_align_events){
            if ($self->all_events || ($current_align_event->event_status eq 'Succeeded') || ($current_align_event->event_status eq 'Abandoned')){
                $current_align_count++;
            }
            else {
                $self->status_message(" $current_align_count alignments have succeeded as part of the current running build ");
                $self->status_message(" Some alignments are still running or have failed ");
                $self->status_message(" CONTINUING WITH POTENTIALLY INCOMPLETE SET OF ALIGNMENTS ");
            }
        }
        #now just get the Succeeded events to pass along for further processing
        # THIS MAY NOT INCLUDE ANY EVENTS
        if($self->all_events) {
            @events = @current_running_build_align_events;
        }
        else {
            @events = Genome::Model::Event->get(event_type => 
                {operator => 'like', value => '%align-reads%'},
                build_id => $current_running_build,
                event_status => 'Succeeded',
                model_id => $model_id,

            );
        }
        # if it does not include any succeeded events - die
        unless (@events) {
            $self->error_message(" No alignments have Succeeded on the current running build ");
            return;
        }
        $align_count = $current_align_count;
    }
    elsif ($last_complete_build){
        my $last_complete_align_count = 0;
        my @last_complete_build_align_events = Genome::Model::Event->get(event_type => 
                {operator => 'like', value => '%align-reads%'},
                    build_id => $last_complete_build,
                    model_id => $model_id,


            );
        foreach my $last_complete_event (@last_complete_build_align_events){
            if ($self->all_events || ($last_complete_event->event_status eq 'Succeeded') || ($last_complete_event->event_status eq 'Abandoned')){
                $last_complete_align_count++;
            }
            else {
            $self->error_message(" $last_complete_align_count alignments have succeeded as part of the last complete build,  some alignments from this build are still running or have failed");
            return;
            }
        }
        if($self->all_events) {
            @events = @last_complete_build_align_events;
        }
        else {
            @events = Genome::Model::Event->get(event_type => 
                {operator => 'like', value => '%align-reads%'},
                build_id => $last_complete_build,
                event_status => 'Succeeded',
                model_id => $model_id,

            );
        }
        unless (@events) {
            $self->error_message(" No alignments have Succeeded on the current running build ");
            return;
        }
        $align_count = $last_complete_align_count;
    }
    else{
        $self->error_message(" No Running or Complete Builds Found ");
        return;
    }

    my %stats_for;
    my %readset_stats;

    #print STDOUT join "\t",("Name","#Reads_Mapped","#Reads_Total","isPaired","#Reads_Mapped_asPaired","Median_Insert_Size","Standard_Deviation_Above_Insert_Size",),"\n";
#Completely undeprecated loop over the readsets
    for my $instrument_data ($last_complete_build->instrument_data) {
        my $library = $instrument_data->library_name;
        unless(defined($library)) {
            $self->error_message("No library defined for ".$instrument_data->id);
            next;
        }
        my $lane_name = $instrument_data->short_name."_".$instrument_data->subset_name;
        my ($alignment) = $last_complete_build->alignment_results_for_instrument_data($instrument_data);
        my @aligner_output = $alignment->aligner_output_file_paths;
        if(@aligner_output > 1) {
            $self->error_message("More than one aligner_output_file! WTF!");
        }
        my $hash = $alignment->get_alignment_statistics($aligner_output[0]);
        $stats_for{$library}{total_read_sets} += 1;
        unless(defined($hash)) {
            #ignore runs where there are no aligner outputs (shouldn't really happen anymore)
            $stats_for{$library}{no_aligner_stats} += 1;
            next;
        }
        $stats_for{$library}{$hash->{isPE}}{mapped} += $hash->{mapped};
        $stats_for{$library}{$hash->{isPE}}{total} += $hash->{total};
        $stats_for{$library}{$hash->{isPE}}{paired} += $hash->{paired};
        $stats_for{$library}{$hash->{isPE}}{read_sets} += 1;
        my $median_insert_size = $instrument_data->median_insert_size;
        my $sd_above_insert_size = $instrument_data->sd_above_insert_size;
        if(defined($median_insert_size) && $hash->{isPE}) {
            $stats_for{$library}{median_insert_size} += $median_insert_size;
            $stats_for{$library}{median_insert_size_n} +=1;
        }
        if(defined($sd_above_insert_size) && $hash->{isPE}) {
            $stats_for{$library}{sd_above_insert_size} += $sd_above_insert_size;
            $stats_for{$library}{sd_above_insert_size_n} += 1;
        }

        #clean things up for printing
        unless(defined($median_insert_size)) {
            $median_insert_size = '-';
        }
        unless(defined($sd_above_insert_size)) {
            $sd_above_insert_size = '-';
        }
        $readset_stats{$lane_name} = "";# join "\t",($lane_name, $hash->{mapped},$hash->{total},$hash->{isPE}, $hash->{paired},$median_insert_size,$sd_above_insert_size,),"\n";
    }
    foreach my $lane (sort keys %readset_stats) {
        print $readset_stats{$lane};
    }
    my $total_lanes = 0;
    my $total_reads = 0;
    my $total_mapped_reads = 0;
    my $total_paired_reads = 0;

    print STDOUT "\n\n",'-' x 5,'Library Averages','-' x 5,"\n";
    foreach my $library (keys %stats_for) {
        print "$library: ",$stats_for{$library}{total_read_sets}, " Total Lanes\n";
        $total_lanes += $stats_for{$library}{total_read_sets};
        if(exists($stats_for{$library}{1})) {
            $total_reads += $stats_for{$library}{1}{total};
            $total_mapped_reads += $stats_for{$library}{1}{mapped};
            $total_paired_reads += $stats_for{$library}{1}{paired};

            print "\tPaired Lanes: ", $stats_for{$library}{1}{read_sets},"\n";
            print "\t\tTotal Reads: ", $stats_for{$library}{1}{total}, "\n";
            print "\t\tMapped Reads: ", $stats_for{$library}{1}{mapped}, "\n";
            print "\t\tPaired Reads: ", $stats_for{$library}{1}{paired}, "\n";
            printf "\t\tPaired Rate: %0.02f%%\n", $stats_for{$library}{1}{paired}/$stats_for{$library}{1}{mapped} * 100; 
            print "\t\tThere were ", $stats_for{$library}{median_insert_size_n}, " out of ", $stats_for{$library}{1}{read_sets}, " lanes where the median insert size was available\n";
            printf "\t\tFrom these the average median insert size was %0.2f\n\n",$stats_for{$library}{median_insert_size}/$stats_for{$library}{median_insert_size_n};


            print "\t\tThere were ", $stats_for{$library}{sd_above_insert_size_n}, " out of ", $stats_for{$library}{1}{read_sets}, " lanes where the sd above the insert size was available\n";
            printf "\t\tFrom these the average sd above the insert size was %0.2f\n\n",$stats_for{$library}{sd_above_insert_size}/$stats_for{$library}{sd_above_insert_size_n};
        }
        if(exists($stats_for{$library}{0})) {

            $total_reads += $stats_for{$library}{0}{total};
            $total_mapped_reads += $stats_for{$library}{0}{mapped};
            print "\tFragment Lanes: ", $stats_for{$library}{0}{read_sets},"\n";
            print "\t\tTotal Reads: ", $stats_for{$library}{0}{total}, "\n";
            print "\t\tMapped Reads: ", $stats_for{$library}{0}{mapped}, "\n";
        }
    }

    #print model totals, this probably shouldn't go in this module but it can sit here for now
    print STDOUT "\n\n",'-' x 5,'Model Averages','-' x 5,"\n";
    print "\tTotal Lanes: ", $total_lanes, "\n";
    printf "\tTotal Runs: %0.02f\n", $total_lanes / 8; 
    print "\tTotal Reads: ", $total_reads, "\n";
    print "\tMapped Reads: ", $total_mapped_reads, "\n";
    print "\tPaired Reads: ", $total_paired_reads, "\n";
    
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
