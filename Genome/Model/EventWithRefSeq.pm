package Genome::Model::EventWithRefSeq;

use strict;
use warnings;

use above "Genome";
use Genome::Model::Event; 

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

    my $result_file = '/tmp/mapmerge_' . $self->model_id;
    $result_file .=  '-' . $ref_seq_id if ($ref_seq_id);
    $result_file .= "-" . $library_name if ($library_name);
    return $result_file;
}

#need to link _mapmerge_locally sub name to resolve_accumulated prolly
sub resolve_accumulated_alignments_filename {
    my $self = shift;
    my %p = @_;
    my $ref_seq_id = $p{ref_seq_id};
    $DB::single=1;
    my $library_name = $p{library_name};
    my $model= Genome::Model->get($self->model_id);
    my @maplists;
    if ($ref_seq_id) {
        @maplists = $model->maplist_file_paths(%p);
    } else {
        @maplists = $model->maplist_file_paths();
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

    my $result_file = $self->mapmerge_filename($ref_seq_id, $library_name);
    my @inputs;
    foreach my $listfile ( @maplists ) {
        my $f = IO::File->new($listfile);
        next unless $f;
        chomp(my @lines = $f->getlines());

        push @inputs, @lines;
    }
    my $found=0;
    if (-f $result_file && -s $result_file) {
        #the file is already present on our blade/environment
        $self->warning_message("Using mapmerge file left over from previous run: $result_file");
        $found=1;
    } elsif(my @host_outputs = $self->find_possible_hosts) {
        #someone may have the file already complete. we should just get it from them via secure copy
        for my $host_output (@host_outputs) {
            my $host=$host_output->value;
            my $cmd = "scp $host:$result_file /tmp/";
            $self->warning_message("Running cmd:$cmd");
            my $rv=system($cmd);
            if($rv != 0){
                $self->warning_message("File not found(or something terrible happened) on $host-- cmd return value was '$rv'. Continuing.");
                next;
            }
            else {
                $self->warning_message("File found on $host");
                $found=1;
                $self->cleanup_tmp_files(1);
                last;
            }
        }           
    }                 

    if($found==0) {
        #no one has a file we want. we should make one and add a note that we have one.
        $self->warning_message("Performing a complete mapmerge.  Hold on...");
        my $cmd = Genome::Model::Tools::Maq::MapMerge->create(use_version => '0.6.5', output => $result_file, inputs => \@inputs);
        $cmd->execute();
        $self->warning_message("mapmerge complete.  output filename is $result_file");
        my ($hostname) = $self->outputs(name => "Hostname");
        if ($hostname) {
            $hostname->value($ENV{HOSTNAME});
        }
        else {
            $self->add_output(name=>"Hostname" , value=>$ENV{HOSTNAME});
        }
    }
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
