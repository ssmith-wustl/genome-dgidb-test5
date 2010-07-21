package Genome::Model::RefSeq;

use strict;
use warnings;

use Genome;
class Genome::Model::RefSeq {
    type_name => 'genome model ref seq',
    table_name => 'GENOME_MODEL_REF_SEQ',
    id_by => [
        model        => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMRS__GM_PK' },
        ref_seq_name => { is => 'VARCHAR2', len => 64 },
    ],
    has => [
        ref_seq_id                     => { is => 'NUMBER', len => 10, is_optional => 1 },
        variation_positions            => { is => 'Genome::Model::VariationPosition', reverse_id_by => 'model_refseq', is_many => 1 },
        variation_position_read_depths => { via => 'variation_positions', to => 'read_depth', is_many => 1 },
        cleanup_tmp_files => {
            is => 'Boolean',
            is_transient => 1,
            is_optional => 1,
            doc => 'set to force cleanup of your tmp mapmerge',
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub resolve_accumulated_alignments_filename {
    my $self = shift;

    $DB::single = $DB::stopper;

    my %p = @_;
    my $ref_seq_id = $p{ref_seq_id};
    my $ref_seq_name = $self->ref_seq_name;
    my $library_name = $p{library_name};
    my $force_use_original_files = $p{force_use_original_files};
    my $identity_length;
    my $remove_pcr_artifacts =$p{remove_pcr_artifacts};
    my $hosts_ref = $p{hosts} ? $p{hosts} : [];

    #are we going to deduplicate? figure this out from a model field.
    #also set the 'length of uniquness'
    my $strategy = $self->model->multi_read_fragment_strategy||'';
    $self->status_message("found multi read fragment strategy $strategy");
    if ($strategy =~ /eliminate start site duplicates\s*(\d*)/) {
        $identity_length = $1 || 26;
        unless(defined $remove_pcr_artifacts) {
            $remove_pcr_artifacts=1;      
        } 
        $self->status_message("removing duplicates with identity length $identity_length...");
    }
    elsif ($strategy) {
        die "unknown strategy $strategy!";
    }

    my $result_file = $self->mapmerge_filename($ref_seq_id, $library_name, remove_pcr_artifacts => $remove_pcr_artifacts);
    my $found=$self->find_previously_created_mapfile($result_file, $hosts_ref);;

    return $result_file if $found;
    
    
    if(0)#$remove_pcr_artifacts) 
    {
        #since deduplicating requires that we have a valid non-duplicated mapfile, we call ourself again to
        #get this mapfile (without the remove_pcr_artifacts option)
        $self->status_message("Removing PCR artifacts");
        my $temp_accum_align_file = $self->resolve_accumulated_alignments_filename(ref_seq_id => $ref_seq_id,library_name => $library_name,remove_pcr_artifacts => 0);
        my $temp_del_file = new File::Temp( UNLINK => 1, SUFFIX => '.map');
        my $result = Genome::Model::Tools::Maq::RemovePcrArtifacts->execute(input => $temp_accum_align_file,keep => $result_file, remove => $temp_del_file->filename, identity_length => $identity_length);
        $self->status_message("Error deduplicating mapfile.\n") unless $result;

        unlink $temp_del_file->filename;
        unless (-e $result_file) {
            $self->error_message("Error creating deduplicated mapfile, $result_file.");
            return;
        }
        unless (-s $result_file) {
            $self->error_message("File $result_file is empty. deduplication failed.");
            unlink $result_file;
            return;    
        }       
    }
    else
    {

        #find maplists that we want to merge
#my @maplists = combine_maplists($library_name);
#        my @maplists;
#        if ($ref_seq_name) {
#            @maplists = $self->maplist_file_paths(%p);
#        } else {
#            @maplists = $self->maplist_file_paths();
#        }
#        unless (@maplists) {
#            $self->error_message("Failed to find maplists!");
#            return;
#        }

        #if they want a library specific map, grep those out.
#        if ($library_name) {
#            my @orig_maplists = @maplists;
#            @maplists = grep { /$library_name/ } @maplists;
#            unless (@maplists) {
#                $self->error_message("Failed to find library $library_name in: @orig_maplists");
#            }
#        }

#        if (!@maplists) {

#            $self->error_message("No maplists found");
#            return;
#        }

#        $ref_seq_id ||= 'all_sequences';

my @inputs = $self->combine_maplists($library_name);
#        my @inputs;
#        foreach my $listfile ( @maplists ) {
#print "$listfile\n";
#            my $f = IO::File->new($listfile);
#            next unless $f;
#            chomp(my @lines = $f->getlines());
#            push @inputs, @lines;
#            $f->close;
#        }
        if (@inputs == 0)
        {
            #do the other method -- readset
        }
        elsif (@inputs == 1) {
            $self->status_message("skipping merge of single-item map list: $inputs[0]");
            return $inputs[0];
        }
        my $inputs = join("\n", @inputs);
        $self->warning_message("Performing a complete mapmerge for $result_file \n"); 
        #$self->warning_message("on $inputs \n ") 
        $self->warning_message("Hold on...\n");

        #my $cmd = Genome::Model::Tools::Maq::MapMerge->create(use_version => '0.6.5', output => $result_file, inputs => \@inputs);
        my ($fh,$maplist) = File::Temp::tempfile;
        $fh->print(join("\n",@inputs),"\n");
        $fh->close;
        my $maq_version=$self->model->read_aligner_version;
        system "gmt maq vmerge --maplist $maplist --pipe $result_file --version $maq_version &";
        my $start_time = time;
        until (-p "$result_file" or ( (time - $start_time) > 100) )  {
            $self->status_message("Waiting for pipe...");
            sleep(5);
        }
        unless (-p "$result_file") {
            die "Failed to make pipe? $!";
        }
        $self->status_message("Streaming into file $result_file.");
        #system "cp $result_file.pipe $result_file";
        unless (-p "$result_file") {
            die "Failed to make map from pipe? $!";
        }

        $self->warning_message("mapmerge complete.  output filename is $result_file");
    }
    ##not sure why this is necessary?
#    my ($hostname) = $self->outputs(name => "Hostname");
#    if ($hostname) {
#        $hostname->value($ENV{HOSTNAME});
#    }
#    else {
#        $self->add_output(name=>"Hostname" , value=>$ENV{HOSTNAME});
#    }

    chmod 00664, $result_file;
    return $result_file;
}

sub combine_maplists
{        
    my $self = shift;
    my $library_name = shift;
        my @maplists;
        @maplists = $self->maplist_file_paths();
        unless (@maplists) {
            $self->error_message("Failed to find maplists!");
            return;
        }

        #if they want a library specific map, grep those out.
        if ($library_name) {
            my @orig_maplists = @maplists;
            @maplists = grep { /$library_name/ } @maplists;
            unless (@maplists) {
                $self->error_message("Failed to find library $library_name in: @orig_maplists");
            }
        } 
       my @inputs;
        foreach my $listfile ( @maplists ) {
            my $f = IO::File->new($listfile);
            next unless $f;
            chomp(my @lines = $f->getlines());
            push @inputs, @lines;
            $f->close;
        }
    return @inputs;
}

sub mapmerge_filename 
{
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


sub find_previously_created_mapfile {
    my $self=shift;
    my $file_to_look_for= shift;
    my $host_outputs = shift;#($self->find_possible_hosts);
    my @host_outputs;

    for my $host ('localhost', map { $_->value } @host_outputs) {
        if ($host eq 'localhost') {
            unless (-f $file_to_look_for) {
                next;
            }
            $self->status_message("Found mapmerge file left over from previous run in /tmp on this host: $file_to_look_for");
        }
        else { 
            my $cmd = "scp $host:$file_to_look_for /tmp/";
            $self->status_message("Copying file from previous host: $cmd");
            my $rv=system($cmd);
            if($rv != 0){
                $self->status_message("File not found(or something terrible happened) on $host-- cmd return value was '$rv'. Continuing.");
                next;
            }
            $self->status_message("Found mapmerge file on $host: $file_to_look_for");
        }

        
        unless (-s $file_to_look_for) {
            $self->error_message("File $file_to_look_for from $host was empty.  Continuing.");
            unlink $file_to_look_for;
            next;
        }
        my @gzip_problems = `gzip -t $file_to_look_for 2>&1`;
        if (@gzip_problems) {
            $self->error_message("Error in gzip file $file_to_look_for!: @gzip_problems");
            unlink $file_to_look_for;
            next;
        }

        
        $self->cleanup_tmp_files(1);
        return 1;
    }
    return 0;
}

sub maplist_file_paths {
    my $self = shift;

    my %p = @_;
    my $ref_seq_name;

    my $model = $self->model;
    my $build = $model->last_complete_build;
    my $accumulated_alignments_directory = $build->data_directory . '/alignments';

    print "Alignments dir: ". $accumulated_alignments_directory ."\n" ;
# TODO:  Do we still need a condition here?
#    if ($self->ref_seq_name) 
#    {
        $ref_seq_name = $self->ref_seq_name;
#    } 
#    else {
#        $ref_seq_id = 'all_sequences';
#    }

    my @map_lists = grep { -e $_ } glob($accumulated_alignments_directory .'/*_'. $ref_seq_name .'.maplist');
    unless (@map_lists) {
        $self->error_message("No map lists found for ref seq $ref_seq_name in " . $accumulated_alignments_directory);
    }
    print "Map lists: ".join("\n",@map_lists);
    return @map_lists;
}
sub DESTROY {
        my $self=shift;
    
       if($self->cleanup_tmp_files) {
           $self->warning_message("cleanup flag set. Removing files we transferred.");
           $self->cleanup_my_mapmerge;
       }
    
        $self->SUPER::DESTROY;
     }

#it is dumb to take a ref_seq for args when we could just call $self->refseq. 
#this is just the first iteration for proof of concept. then we'll refactor it to not be dumb
sub cleanup_my_mapmerge {
    my $self=shift;
    my @files = glob($self->mapmerge_filename($self->ref_seq_id) . "*");
    unlink(@files);
} 
1;
