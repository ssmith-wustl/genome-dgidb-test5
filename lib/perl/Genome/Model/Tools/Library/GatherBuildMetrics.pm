package Genome::Model::Tools::Library::GatherBuildMetrics;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Library::GatherBuildMetrics {
    is => 'Command',
    has => [
    build_id => { 
        type => 'String',
        is_optional => 0,
        doc => "build id of the build to gather metrics for",
    },
    mapcheck_dir => {
        type => 'String',
        is_optional => 1,
        doc => "directory containing mapcheck output for each lane in a model",
    },
    ]
};


sub execute {
    my $self=shift;
    $DB::single = 1;
    my $build_id = $self->build_id;

    my $build = Genome::Model::Build->get($build_id);
    unless(defined($build)) {
        $self->error_message("Unable to find build $build_id");
        return;
    }
    my $model = $build->model;
    unless(defined($model)) {
        $self->error_message("Somehow this build does not have a model");
        return;
    }
    printf STDERR "Grabbing information for model %s (build %s)\n", $model->name, $build->build_id;       
    #Grab all alignment events so we can filter out ones that are still running or are abandoned
    # get all align events for the current running build
    my @align_events = Genome::Model::Event->get(event_type => 
        {operator => 'like', value => '%align-reads%'},
        build_id => $build,
        model_id => $model->id,
    );
    printf STDERR "%d lanes in build\n", scalar(@align_events);
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
        $self->error_message(" No alignments have Succeeded on the build ");
        return;
    }
    printf STDERR "Using %d lanes to calculate metrics\n", scalar(@events);

    my %stats_for;
    my %readset_stats;

    #print STDOUT join "\t",("Name","#Reads_Mapped","#Reads_Total","isPaired","#Reads_Mapped_asPaired","Median_Insert_Size","Standard_Deviation_Above_Insert_Size",),"\n";
#Completely undeprecated loop over the readsets
    for my $instrument_data ($build->instrument_data) {
        my $library = $instrument_data->library_name;
        unless(defined($library)) {
            $self->error_message("No library defined for ".$instrument_data->id);
            next;
        }
        my $lane_name = $instrument_data->short_name."_".$instrument_data->subset_name;
        my ($alignment) = $build->alignment_results_for_instrument_data($instrument_data); 
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
        my $read1 = GSC::RunLaneSolexa->get($instrument_data->fwd_seq_id);
        my $read2 = GSC::RunLaneSolexa->get($instrument_data->rev_seq_id);
        if($read2 && $read2->run_type eq 'Paired End Read 1') {
            #assume the other is read2
            ($read1, $read2) = ($read2, $read1);
        }
        my ($error1, $error2) = ($read1 ? $read1->filt_error_rate_avg : '-', $read2 ? $read2->filt_error_rate_avg : '-');
        $error1 ||= '-';
        $error2 ||= '-';
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
        my $gerald_clusters = $instrument_data->clusters;
        my $fwd_gerald_alignment_rate = $instrument_data->fwd_filt_aligned_clusters_pct;
        my $rev_gerald_alignment_rate = $instrument_data->rev_filt_aligned_clusters_pct;
        $fwd_gerald_alignment_rate |= '-';
        $rev_gerald_alignment_rate |= '-';
        
        my $bases_read = $instrument_data->total_bases_read;
        my $cycles = $instrument_data->cycles;
        $stats_for{$library}{$hash->{isPE}}{total_clusters} += $gerald_clusters;
        $stats_for{$library}{$hash->{isPE}}{total_gbp} += $bases_read / 1_000_000_000;
        if($self->mapcheck_dir) {
            my $haploid_coverage_file = $self->mapcheck_dir . "/$lane_name/$lane_name.mapcheck";
            my $haploid_coverage = '-';

            my $fh = IO::File->new($haploid_coverage_file, "r");
            unless($fh) {
                $self->error_message("Unable to open $haploid_coverage_file");
                return;
            }
            my ($line) = grep { $_ =~ /Average depth across all non-gap regions:/ } $fh->getlines;
            ($haploid_coverage) = $line =~ /([0-9\.]+)$/;
            $readset_stats{$lane_name} = join "\t",($lane_name,$library, $hash->{mapped},$hash->{total},$hash->{isPE}, $hash->{paired},$median_insert_size,$sd_above_insert_size,$gerald_clusters, $cycles, $error1, $error2, $fwd_gerald_alignment_rate, $rev_gerald_alignment_rate, sprintf("%0.02f",$hash->{mapped}/$hash->{total}),),$haploid_coverage,"\n";
        }
        else {
            $readset_stats{$lane_name} = join "\t",($lane_name,$library, $hash->{mapped},$hash->{total},$hash->{isPE}, $hash->{paired},$median_insert_size,$sd_above_insert_size,$gerald_clusters, $cycles, $error1, $error2, $fwd_gerald_alignment_rate, $rev_gerald_alignment_rate, sprintf("%0.02f",$hash->{mapped}/$hash->{total}),),"\n";
        }
    }
    print("Flowcell_Lane\tLibrary\t#Reads_Mapped\t#Reads_Total\tMapped_as_PE\t#Mapped_as_Pairs\tMedian_Insert_Size\tSD_Above_Insert_Size\tFiltered_Clusters\tCycles(Read_Length+1)\tRead1_Avg_Error_Rate\tRead2_Avg_Error_Rate\tRead1_ELAND_Mapping_Rate\tRead2_ELAND_Mapping_Rate\tMaq_Mapping_Rate"); 
    if($self->mapcheck_dir) {
        print "\tHaploid_Coverage";
    }
    print "\n";
    
    foreach my $lane (sort keys %readset_stats) {
        print $readset_stats{$lane};
    }
    my $total_lanes = 0;
    my $total_reads = 0;
    my $total_mapped_reads = 0;
    my $total_paired_reads = 0;
    my $total_clusters = 0;
    my $total_gbp = 0;

    print STDOUT "\n\n",'-' x 5,'Library Averages','-' x 5,"\n";
    foreach my $library (keys %stats_for) {
        print "$library: ",$stats_for{$library}{total_read_sets}, " Total Lanes\n";
        $total_lanes += $stats_for{$library}{total_read_sets};
        if(exists($stats_for{$library}{1})) {
            $total_reads += $stats_for{$library}{1}{total};
            $total_mapped_reads += $stats_for{$library}{1}{mapped};
            $total_paired_reads += $stats_for{$library}{1}{paired};
            $total_clusters += $stats_for{$library}{1}{total_clusters};
            $total_gbp += $stats_for{$library}{1}{total_gbp};

            print "\tPaired Lanes: ", $stats_for{$library}{1}{read_sets},"\n";
            print "\t\tFiltered Clusters: ", $stats_for{$library}{1}{total_clusters}, "\n";
            print "\t\tGbp: ", $stats_for{$library}{1}{total_gbp}, "\n";
            print "\t\tTotal Reads: ", $stats_for{$library}{1}{total}, "\n";
            print "\t\tMapped Reads: ", $stats_for{$library}{1}{mapped}, "\n";
            printf "\t\tMapping Rate: %0.02f%%\n", $stats_for{$library}{1}{mapped}/$stats_for{$library}{1}{total} * 100;
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
            print "\t\tFiltered Clusters: ", $stats_for{$library}{0}{total_clusters}, "\n";
            print "\t\tGbp: ", $stats_for{$library}{0}{total_gbp}, "\n";
            print "\t\tTotal Reads: ", $stats_for{$library}{0}{total}, "\n";
            print "\t\tMapped Reads: ", $stats_for{$library}{0}{mapped}, "\n";
            printf "\t\tMapping Rate: %0.02f%%\n", $stats_for{$library}{0}{mapped}/$stats_for{$library}{0}{total} * 100;
        }
    }

    #print model totals, this probably shouldn't go in this module but it can sit here for now
    print STDOUT "\n\n",'-' x 5,'Model Averages','-' x 5,"\n";
    print "\tTotal Lanes: ", $total_lanes, "\n";
    printf "\tTotal Runs: %0.02f\n", $total_lanes / 8; 
    print "\tTotal Clusters: ", $total_clusters,"\n";
    print "\tTotal Gbp: ", $total_gbp,"\n";
    print "\tTotal Reads: ", $total_reads, "\n";
    print "\tMapped Reads: ", $total_mapped_reads, "\n";
    printf "\tMapping Rate: %0.02f%%\n", $total_mapped_reads/$total_reads * 100;
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
