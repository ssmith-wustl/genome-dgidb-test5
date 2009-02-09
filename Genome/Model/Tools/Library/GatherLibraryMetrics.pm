package Genome::Model::Tools::Library::GatherLibraryMetrics;

use strict;
use warnings;

use Genome;
use Genome::RunChunk; # get access to GSC namespace
use Command;
use IO::File;
use GSCApp; 
App->init;

class Genome::Model::Tools::Library::GatherLibraryMetrics {
    is => 'Command',
    has => [
    model_id => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "model id of the model to gather library metrics for",
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

    #Grab all alignment events so we can filter out ones that are still running or are abandoned
    my @events = Genome::Model::Event->get(event_type => 
        {operator => 'like', value => '%align-reads%'},
        model_id => $model_id,
        event_status => 'Succeeded'
    );
    #Convert events to ReadSet objects
    my @readsets = map {Genome::Model::ReadSet->get(read_set_id => $_->read_set_id, model_id => $model_id)} @events;

    my %stats_for;
    my %readset_stats;

        print STDOUT join "\t",("Name","#Reads_Mapped","#Reads_Total","isPaired","#Reads_Mapped_asPaired","Median_Insert_Size","Standard_Deviation_Above_Insert_Size",),"\n";
#Completely undeprecated loop over the readsets
    foreach my $read_set_link (@readsets) {
        my $library = $read_set_link->library_name;
        unless(defined($library)) {
            $self->error_message("No library defined for ".$read_set_link->read_set_id);
            next;
        }
        my $hash = $read_set_link->get_alignment_statistics;
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
        my $sls = GSC::RunLaneSolexa->get($read_set_link->read_set_id); 
        unless(defined($sls)) {
            $self->error_message("Unable to find RunLaneSolexa object for ".$read_set_link->read_set_id);
            next;
        }
        my $median_insert_size = $sls->median_insert_size;
        my $sd_above_insert_size = $sls->sd_above_insert_size;
        my $lane_name = $read_set_link->short_name."_".$read_set_link->subset_name;
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
        $readset_stats{$lane_name} = join "\t",($lane_name, $hash->{mapped},$hash->{total},$hash->{isPE}, $hash->{paired},$median_insert_size,$sd_above_insert_size,),"\n";
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
