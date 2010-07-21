package Genome::Model::Tools::Library::CreateLibraryMapFiles;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Library::CreateLibraryMapFiles {
    is => 'Command',
    has => [
    model_id => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "model id of the model to dump per library map files for",
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
            if (($current_align_event->event_status eq 'Succeeded') || ($current_align_event->event_status eq 'Abandoned')){
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
        @events = Genome::Model::Event->get(event_type => 
                    {operator => 'like', value => '%align-reads%'},
                    build_id => $current_running_build,
                    event_status => 'Succeeded',
                     model_id => $model_id,

                    );
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
            if (($last_complete_event->event_status eq 'Succeeded') || ($last_complete_event->event_status eq 'Abandoned')){
                $last_complete_align_count++;
            }
            else {
            $self->error_message(" $last_complete_align_count alignments have succeeded as part of the last complete build,  some alignments from this build are still running or have failed");
            return;
            }
        }
        @events = Genome::Model::Event->get(event_type => 
                    {operator => 'like', value => '%align-reads%'},
                    build_id => $last_complete_build,
                    event_status => 'Succeeded',
                      model_id => $model_id,


                    );
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
    #Convert events to InstrumentDataAssignment objects
    my @idas = map { $_->instrument_data_assignment } @events;
    
    my %map_files;
    #Completely undeprecated loop over the instrument data assignments
    foreach my $ida (@idas) {
        my @files = $ida->alignment_file_paths; #this should work now, and will include things aligned to non-chromosomal references 
        push @{$map_files{$ida->library_name}}, @files;
    }

    foreach my $library (keys %map_files) {
        my @fof = @{$map_files{$library}};
        
        unless(@fof && defined($fof[0])) {
            delete $map_files{$library}; #remove libraries where there were no map files, shouldn't happen
            next;
        }
        
        @fof = grep {!-z $_} @fof; #recommended by the great and powerful Chris Harris

        unless(@fof) {
            delete $map_files{$library}; #unhappy with repeating this, but check may be needed
            next;
        }

        #dump out the map file paths into a file
        my $fh = new IO::File "${model_id}_${library}_readsets.fof","w";
        if(defined($fh)) {
            print $fh join("\n",@fof), "\n"; #must end in a new-line or the vmerge tool will hang horribly
        }
    }
    
    #Here determine what version of vmerge to use
    my $aligner = $model->read_aligner_name;
    
    #use aligner info to use the proper maq
    my $maq;
    if($aligner eq 'maq0_6_8') {
        $maq = "/gsc/pkg/bio/maq/maq-0.6.8_x86_64-linux/maq";
    }
    elsif($aligner eq 'maq0_7_1') {
        $maq = "/gsc/pkg/bio/maq/maq-0.7.1-64/bin/maq";
    }

    #That's right I'm dynamically generating a bash script 
    #deal with it
    #At some point this will need to be moved to a file or something in order to avoid truncation by bash
    
    my $i;
    my $bash_script = "case \$LSB_JOBINDEX in\n";
    my @libraries = sort keys %map_files;
    
    
    unless(@libraries) {
        $self->error_message("No libraries with data found for model $model_id");
        return;
    }

    
    my $num_libraries = scalar @libraries;
    for($i = 0; $i < $num_libraries; ++$i) {
        $bash_script .= sprintf "\t%d)\nLIBRARY=%s\nexport LIBRARY\n;;\n",$i+1, $libraries[$i];
    }
    $bash_script .= "esac\n";

    #TODO Fix this back to deployed vmerge once harris deploys it
    my $commands = <<"COMMANDS";
perl -I ~/src/perl-modules/trunk `which gmt` maq vmerge --maplist ${model_id}_\${LIBRARY}_readsets.fof --pipe /tmp/${model_id}_\${LIBRARY}.map --version $aligner & 
mkdir -p -m a+rw \${LIBRARY}
sleep 5
$maq rmdup \${LIBRARY}/\${LIBRARY}.rmdup.map /tmp/${model_id}_\${LIBRARY}.map
COMMANDS

#now we have all the files, send out the jobs
system("bsub -N -u \${USER}\@watson.wustl.edu -R '-R 'select[mem>500 && type==LINUX64] rusage[mem=500]' -J '${model_id}_library_vmerge[1-$num_libraries]' -oo 'stdout.\%I' -eo 'stderr.\%I' '$bash_script$commands'");

    return 1;
}


1;

sub help_brief {
    "Merges all runs into a single map file for each library of a model and puts them in their own directories"
}

sub help_detail {
    <<'HELP';
This script uses the Genome Model API to grab out all alignment events for a model and produce a maq .map file for each library in the model. Only runs which have the status 'Succeeded' are used. The script wraps the vmerge tool and will produce an fof file containing the paths to the per-run map files generated by the pipeline for each library in the working directory. It also creates directories for each library name found (inside the current working directory), and places a single .map file for the library inside the directory. User will receive an email indicating when the vmerge events complete. Expect one email for each library.
HELP
}
