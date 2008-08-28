package Genome::Model::EventWithRefSeq;

use strict;
use warnings;

use Genome;
use Genome::Model::Event; 
use File::Temp;

class Genome::Model::EventWithRefSeq {
    is => 'Genome::Model::Event',
    is_abstract => 1,
    sub_classification_method_name => '_get_sub_command_class_name',
    has => [
        ref_seq_id => { is => 'Integer', doc => 'Identifies the refseq'},
        cleanup_tmp_files => { is => 'Boolean', doc => 'set to force cleanup of your tmp mapmerge' },
    ],
};

sub desc {
    my $self = shift;
    my $desc = $self->SUPER::desc;
    $desc .= " for refseq " . $self->ref_seq_id . " on build " . $self->parent_event_id;
    return $desc;
}

#it is dumb to take a ref_seq for args when we could just call $self->refseq. 
#this is just the first iteration for proof of concept. then we'll refactor it to not be dumb
sub mapmerge_filename {
    my $self=shift;
    my $ref_seq_id=shift;
    my $library_name=shift;
    my %p = @_;
    my $remove_pcr_artifacts = $p{remove_pcr_artifacts};

    my $result_file = '/tmp/mapmerge_' . $self->model_id;
    $result_file .=  '-' . $ref_seq_id if ($ref_seq_id);
    $result_file .= "-" . $library_name if ($library_name);
    $result_file .= '-ssdedup' if ($remove_pcr_artifacts);
    
    return $result_file;
}

#need to link _mapmerge_locally sub name to resolve_accumulated prolly
sub resolve_accumulated_alignments_filename {
    my $self = shift;
    
    $DB::single = $DB::stopper;

    my %p = @_;
    my $ref_seq_id = $p{ref_seq_id};
    my $library_name = $p{library_name};
    my $force_use_original_files = $p{force_use_original_files};
    my $remove_pcr_artifacts = $p{remove_pcr_artifacts};
    my $identity_length = $p{remove_pcr_artifacts_identity_length};

    unless (exists $p{remove_pcr_artifacts}) {
        # the caller didn't explicitly state whether we should de-duplicate
        # check the model
        my $strategy = $self->model->multi_read_fragment_strategy||'';
        $self->status_message("found multi read fragment strategy $strategy");
        if ($strategy =~ /eliminate start site duplicates\s*(\d*)/) {
            my $identity_length = $1 || 0;
            $self->status_message("removing duplicates with identity length $identity_length...");
            $remove_pcr_artifacts = 1;
        }
        elsif ($strategy) {
            die "unknown strategy $strategy!";
        }
    }

    if ($remove_pcr_artifacts and not exists $p{remove_pcr_artifacts_identity_length}) {
        $identity_length = 26;
    }

    my $model= Genome::Model->get($self->model_id);
    my @maplists;
    if ($ref_seq_id) {
        @maplists = $model->maplist_file_paths(%p);
    } else {
        @maplists = $model->maplist_file_paths();
    }
    unless (@maplists) {
        $self->error_message("Failed to find maplists!");
        return;
    }

    if ($library_name) {
        my @orig_maplists = @maplists;
        @maplists = grep { /$library_name/ } @maplists;
        unless (@maplists) {
            $self->error_message("Failed to find library $library_name in: @orig_maplists");
        }
    }

    if (!@maplists) {
        $self->error_message("No maplists found");
        return;
    }

    $ref_seq_id ||= 'all_sequences';

    my $result_file = $self->mapmerge_filename($ref_seq_id, $library_name, %p);
    my @inputs;
    foreach my $listfile ( @maplists ) {
        my $f = IO::File->new($listfile);
        next unless $f;
        chomp(my @lines = $f->getlines());
        push @inputs, @lines;
    }
    
    my $found=0;
    unless ($force_use_original_files) {
        # unless specifically requested, we'll try to "borrow" a copy of the file 
        # from the current /tmp or from a previous step's temp file

        #someone may have the file already complete. we should just get it from them via secure copy
        my @host_outputs = ($self->find_possible_hosts);
        for my $host ('localhost', map { $_->value } @host_outputs) {
            if ($host eq 'localhost') {
                unless (-f $result_file) {
                    next;
                }
                $self->status_message("Found mapmerge file left over from previous run in /tmp on this host: $result_file");
            }
            else { 
                my $cmd = "scp $host:$result_file /tmp/";
                $self->status_message("Copying file from previous host: $cmd");
                my $rv=system($cmd);
                if($rv != 0){
                    $self->status_message("File not found(or something terrible happened) on $host-- cmd return value was '$rv'. Continuing.");
                    next;
                }
                $self->status_message("Found mapmerge file on found on $host: $result_file");
            }
            unless (-s $result_file) {
                $self->error_message("File $result_file from $host was empty.  Continuing.");
                unlink $result_file;
                next;
            }
            my @gzip_problems = `gzip -t $result_file 2>&1`;
            if (@gzip_problems) {
                $self->error_message("Error in gzip file $result_file!: @gzip_problems");
                unlink $result_file;
                next;
            }
            $found=1;
            $self->cleanup_tmp_files(1);
            last;
        }
    }

    if($found==0) {
        #no one has a file we want. we should make one and add a note that we have one.
        if($remove_pcr_artifacts)
        {
            #since deduplicating requires that we have a valid non-duplicated mapfile, we call ourself again to
            #get this mapfile (without the remove_pcr_artifacts option)
            print "Removing PCR artifacts\n";
            my $temp_accum_align_file = $self->resolve_accumulated_alignments_filename(ref_seq_id => $ref_seq_id,library_name => $library_name,remove_pcr_artifacts => 0);
            my $temp_del_file = new File::Temp( UNLINK => 1, SUFFIX => '.map');
            my $result = Genome::Model::Tools::Maq::RemovePcrArtifacts->execute(input => $temp_accum_align_file,keep => $result_file, remove => $temp_del_file->filename, identity_length => $identity_length);
            $self->status_message("Error deduplicating mapfile.\n") unless $result;
            unlink $temp_del_file->filename;
            unless (-e $result_file) {
                $self->error_message("Error creating deduplicated mapfile, $result_file.");
                next;
            }
            unless (-s $result_file) {
                $self->error_message("File $result_file is empty.  Continuing.");
                unlink $result_file;
                next;
            }       
        }
        else
        {
            if (@inputs == 1) {
                $self->status_message("skipping merge of single-item map list: $inputs[0]");
                return $inputs[0];
            }

            $self->warning_message("Performing a complete mapmerge for $result_file using @inputs.  Hold on...");

            #my $cmd = Genome::Model::Tools::Maq::MapMerge->create(use_version => '0.6.5', output => $result_file, inputs => \@inputs);
            my ($fh,$maplist) = File::Temp::tempfile;
            $fh->print(join("\n",@inputs),"\n");
            $fh->close;
            system "gt maq vmerge --maplist $maplist --pipe $result_file.pipe &";
            my $start_time = time;
            until (-p "$result_file.pipe" or ( (time - $start_time) > 100) )  {
                $self->status_message("Waiting for pipe...");
                sleep(5);
            }
            unless (-p "$result_file.pipe") {
                die "Failed to make pipe? $!";
            }
            $self->status_message("Streaming into file $result_file.");
            system "cp $result_file.pipe $result_file";
            unless (-s "$result_file") {
                die "Failed to make map from pipe? $!";
            }

            $self->warning_message("mapmerge complete.  output filename is $result_file");
        }
        my ($hostname) = $self->outputs(name => "Hostname");
        if ($hostname&&!$hostname->value) {
            $hostname->value($ENV{HOSTNAME});
        }
        else {
           $self->add_output(name=>"Hostname" , value=>$ENV{HOSTNAME});
        }
    }
    chmod 00664, $result_file;
    return $result_file;
}

#it is dumb to take a ref_seq for args when we could just call $self->refseq. 
#this is just the first iteration for proof of concept. then we'll refactor it to not be dumb
sub cleanup_my_mapmerge {
    my $self=shift;
    my $ref_seq_id=$self->ref_seq_id;
    my @files = glob($self->mapmerge_filename($ref_seq_id) . "*");
    unlink(@files);
}

sub cleanup_all_mapmerges {
    my $self = shift;
    my $ref_seq_id = shift;
       
    for my $host_output (my @host_outputs= $self->find_possible_hosts) {
        my $host = $host_output->value;
        my $cmd = "ssh $host 'rm /tmp/mapmerge_" . $self->model_id . "*";
        $self->warning_message("Running $cmd");
        my $rv = system($cmd);
        
        if($rv && $rv!=0) {
            $self->warning_message("nonzero exit code $rv from $cmd");
        }
        else{
           $self->warning_message("Removed file from $host. Deleting db entry referencing it.");
           $host_output->delete;
        }
    }
}
sub cleanup_the_mapmerge_I_specify {
    my $self=shift;
    my $output=shift;
    my $host = $output->value;
    
    my $cmd = "ssh $host 'rm /tmp/mapmerge_" . $self->model_id . "*'";
    $self->warning_message("Running $cmd");
    my $rv = system($cmd);
    if($rv && $rv!=0) {
        $self->warning_message("nonzero exit code $rv from $cmd");
    }
    else{
        $self->warning_message("Removed file from $host.");
    }
}

1;


sub find_possible_hosts {
    my $self = shift;
    my $ref_seq_id = $self->ref_seq_id;
    my @host_outputs;
    my $current=$self;
    my $previous;
    while(defined $current->prior_event_id) {
        $previous = Genome::Model::Event->get($current->prior_event_id);
        my @output = Genome::Model::Event::Output->get(name => "Hostname", event_id=> $previous->id);
        push @host_outputs, @output;
        $current = $previous;
    }
    return @host_outputs if wantarray;
    return \@host_outputs;
}

sub DESTROY {
   my $self=shift;

   if($self->cleanup_tmp_files) {
      $self->warning_message("cleanup flag set. Removing files we transferred."); 
      $self->cleanup_my_mapmerge;
  }      

   $self->SUPER::DESTROY;
}   
