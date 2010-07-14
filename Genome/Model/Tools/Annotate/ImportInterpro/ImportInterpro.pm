package Genome::Model::Tools::Annotate::ImportInterpro;

use strict;
use warnings;
use Genome;
use Bio::Seq;
use Bio::SeqIO;
use Bio::Tools::GFF;
use File::Temp;
use Benchmark;

my $low  = 1000;
my $high = 20000;
UR::Context->object_cache_size_lowwater($low);
UR::Context->object_cache_size_highwater($high);

class Genome::Model::Tools::Annotate::ImportInterpro{
    is => 'Genome::Model::Tools::Annotate',
    has => [
        reference_transcripts => {
            is => 'String',
            is_input => 1, 
            is_optional => 0,
            doc => 'provide name/version number of the reference transcripts set you would like to use ("NCBI-human.combined-annotation/0").',
        },
    ],
    has_optional => [
        interpro_version => { 
            is => 'Number',
            is_input => 1,
            is_optional => 1,
            default => 4.5,
            doc => 'Version of Interpro used.  This option is currently nonfunctional  The default is 4.5',
        },
        chunk_size => {
            is => 'Number',
            is_input => 1,
            is_optional => 1,
            default => 25000,
            doc => 'Number of sequences submitted to interpro at a time.  Defaults to 25000',
        },
        commit_size => {
            is => 'Number',
            is_input => 1,
            is_optional => 1,
            default => 100,
            doc => 'Number of Interpro results saved at a time.  Defaults to 100',
        },
        benchmark => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
            is_input => 1,
            doc => 'if set, run times are displayed as status messages after certain steps are completed (x, y, z, etc)',
        },
        log_file => { 
            is => 'Path',
            is_optional => 1,
            default => '/dev/null',
            is_input => 1,
            doc => 'if set, STDOUT and STDERR are directed to this file path for logging purposes.  Defaults to /dev/null'
        },
        tmp_dir => { 
            is => 'Path',
            is_optional => 1,
            default => '/tmp',
            is_input => 1,
            doc => 'if set, temporary files for fasta generation, iprscan output, etc. are written to this directory.  Defaults to /tmp'
        },
    ],
};

sub help_synopsis {
    return <<EOS
gmt annotate import-interpro --reference-transcripts NCBI-human.combined-annotation/54_36p
EOS
}

sub help_detail{
    return <<EOS
This runs the interpro import.  It takes the name and version number of the set of reference transcripts.

The current version uses IPRscan version 4.5.  Work in in progress to add support for other versions of IPRscan.

This tool runs all of the transcripts in the set through IPRscan, parses the results, and creates a Genome::InterproResults object for each result
EOS
}

sub execute {
    my $self = shift;
   
    my $total_start = Benchmark->new;
   
    my $log_file = $self->log_file; #TODO: sanity check this
    open (OLDOUT, ">&STDOUT");
    open (OLDERR, ">&STDERR");

    open(STDOUT, "> $log_file") or die "Can't redirect STDOUT: $!";
    open(STDERR, "> $log_file") or die "Can't redirect STDERR: $!";
   
    my ($model_name, $build_version) = split("/", $self->reference_transcripts);
    my $model = Genome::Model->get(name => $model_name);
    die "Could not get model $model_name" unless $model;
    my $build = $model->build_by_version($build_version);
    die "Could not get imported annotation build version $build_version" unless $build;
    my $transcript_iterator = $build->transcript_iterator;
    die "Could not get iterator" unless $transcript_iterator;
    my $chunk_size = $self->chunk_size;
    die "Could not get chunk-size $chunk_size" unless $chunk_size; 
    die "chunk-size of $chunk_size is invalid.  Must be between 1 and 50000" if($chunk_size > 50000 or $chunk_size < 1);
    my $commit_size = $self->commit_size;
    die "Could not get commit-size $commit_size" unless $commit_size; 
    die "commit-size of $commit_size is invalid.  Must be greater than 1" if($commit_size < 1);
    my $iprscan_dir = '/gsc/scripts/pkg/bio/iprscan/iprscan-'.$self->interpro_version; #defaults to 4.5; 
    die "Could not find interpro version ".$self->interpro_version unless -d $iprscan_dir; 

    #converter.pl requires this environment variable to be set to the iprscan directory.  It refuses to run if this isn't set
    my $old_iprscan_home = $ENV{'IPRSCAN_HOME'}; #save this value so it can be reset at the end of the script
    $ENV{'IPRSCAN_HOME'} = $iprscan_dir; 

    my $tmp_dir = $self->tmp_dir;
    die "Could not get tmp directory $tmp_dir" unless $tmp_dir; #TODO: Sanity check this

    #If this file exists, it should contain the last transcript that was successfully turned into interpro results.  If the processes completes successfully, this file should be unlinked
    my $status_file = $build->data_directory . "/import_interpro_status_file";  
    
    #Generate .fasta files frome the build to be submitted wtih iprscan 
    my $pre_fasta_generation = Benchmark->new;
    
    #Try to pick-up where we left off if a previous run failed out in the object creation stage
    my $transcript;
    my $interpro_result_counter = 1;
    if(-s $status_file){ #pick up where we left off if there's a status file with a size
        #grab the last transcript, which is contained in the last line of the status_file  
        my $status_file_handle = IO::File->new($status_file, "w") or die "Could not open status_file $status_file, exiting";
        my $last_line;
        while (my $line = <$status_file_handle>){
            $last_line = $line;
        }
        $status_file_handle->close;
        my ($transcript_data_dir, $transcript_name) = split("\t", $last_line);
        my $last_transcript = Genome::Transcript->get(data_directory=>$transcript_data_dir, 
                                                      transcript_name => $transcript_name,); 
        
        #Grab all the interproresults for the last transcript.  
        my @interpro_results = Genome::InterproResult->get(transcript_name => $last_transcript->transcript_name,
                                                           data_directory => $last_transcript->data_directory,
                                                           chrom_name => $last_transcript->chrom_name,
                                                          );
       
       #Figure out the max id of those results and set $interpro_results_counter to that number + 1.  
        for my $result (@interpro_results){
            if($result->interpro_id > $interpro_result_counter){
                $interpro_result_counter = $result->interpro_id; 
            }
        }
        $interpro_result_counter++; #Start at one more than the highest id to avoid collisions
       
       #Wipe out those results.
        for my $result (@interpro_results){
           $result->delete();
        }
        
        #Get transcript_iterator in the right place.  
        while($transcript = $transcript_iterator->next){
            #TODO: compare the transcript to the transcript line.  If they match, call $transcript_iterator->next and call last;
        }
    }else{ #This either succeeded last time, or has never been run on this reference_transcripts set.  Set $transcript to the first transcript and go!
        $transcript = $transcript_iterator->next;
    }
    
    #Now that we know where to start, write some transcript fastas to feed into interpro
    my %fastas; 
    my ($fasta_temp, $fasta, $fasta_writer);
    my $transcript_counter = 0; 
    while (defined $transcript){
        if ($transcript_counter >= $chunk_size or not defined $fasta_temp){
            if (defined $fasta_temp){
                $fastas{$fasta} = $fasta_temp;
            }
            $fasta_temp = File::Temp->new(UNLINK => 0, 
                                          DIR => $tmp_dir,
                                          TEMPLATE => 'import-interpro_fasta_XXXXXX');
            $fasta = $fasta_temp->filename; 
            $fasta_writer = new Bio::SeqIO(-file => ">$fasta", -format => 'fasta');
            die "Could not get fasta writer" unless $fasta_writer;
            $transcript_counter = 0;
        }
        my $protein = $transcript->protein;
        unless ($protein){
            $transcript = $transcript_iterator->next;
            next;
        }
        $DB::single = 1;
        my $amino_acid_seq = $protein->amino_acid_seq;
        my $bio_seq = Bio::Seq->new(-display_id => $transcript->transcript_name,
                                    -seq => $amino_acid_seq);
        $fasta_writer->write_seq($bio_seq);
        $transcript_counter++; 
        $transcript = $transcript_iterator->next;
    }

    unless (exists $fastas{$fasta}){
        $fastas{$fasta} = $fasta_temp;
    }

    my $post_fasta_generation = Benchmark->new;
    my $fasta_generation_time = timediff($post_fasta_generation, $pre_fasta_generation);
    $self->status_message('.fasta generation: ' . timestr($fasta_generation_time, 'noc')) if $self->benchmark;

    #Run each .fasta through iprscan and throw the results into a tab delimited temp file
    my $pre_iprscan = Benchmark->new;
    my %iprscan;
    for my $fasta_file (keys %fastas){
        my $iprscan_temp = File::Temp->new(UNLINK => 0,
                                           DIR => $tmp_dir,
                                           TEMPLATE => 'import-interpro_iprscan-result_XXXXXX');
        my $iprscan_output = $iprscan_temp->filename;
        Genome::Utility::FileSystem->shellcmd(cmd => $iprscan_dir.'/bin/iprscan -cli -i ' . $fasta_file . ' -o ' . $iprscan_output . ' -seqtype p -appl hmmpfam -iprlookup -goterms -verbose -format raw',) or die "iprscan failed: $!"; 
        $iprscan{$iprscan_output} = $iprscan_temp;
    }
    my $post_iprscan = Benchmark->new;
    my $iprscan_time = timediff($post_iprscan, $pre_iprscan);
    $self->status_message('iprscan: ' . timestr($iprscan_time, 'noc')) if $self->benchmark;

    #Merge the tab delimited temp files containing the results from the iprscan(s) into a single tab delimimted file
    my $pre_iprscan_merger = Benchmark->new; 

    my $iprscan_merged = File::Temp->new(UNLINK => 0,
                                         DIR => $tmp_dir,
                                         TEMPLATE => 'import-interpro_iprscan-merged-results_XXXXXX');
    my $iprscan_merged_path = $iprscan_merged->filename;
    for my $iprscan_path (keys %iprscan){
        my $fh = $iprscan{$iprscan_path};
        while (my $line = <$fh>){
            chomp ($line);
            print $iprscan_merged $line."\n";;    
        }
    }
    my $post_iprscan_merger = Benchmark->new;
    my $iprscan_merger_time = timediff($post_iprscan_merger, $pre_iprscan_merger);
    $self->status_message('iprscan results merger: ' . timestr($iprscan_merger_time, 'noc')) if $self->benchmark;
    
    #Convert the merged iprscan results into a .gff3 file
    my $pre_gff_conversion = Benchmark->new;
    my $converter_lib = '/lib';
    my $converter_cmd = '/bin/converter.pl';
    my $converter_temp = File::Temp->new(UNLINK => 0,
                                         DIR => $tmp_dir,
                                         TEMPLATE => 'import-interpro_iprscan-results-converted_XXXXXX');
    my $converter_output = $converter_temp->filename;
    #the perl -I is used to ensure that the iprscan lib is included in the path.  This may no longer be necessary, as we are using the version on /gsc/scripts
    Genome::Utility::FileSystem->shellcmd(cmd => "perl -I " . $iprscan_dir.$converter_lib . " " . $iprscan_dir.$converter_cmd . " --input " . $iprscan_merged_path . " --output " . $converter_output . " --format gff3",) or die "gff conversion failed: $!";
    my $post_gff_conversion = Benchmark->new;
    my $gff_conversion_time = timediff($post_gff_conversion, $pre_gff_conversion);
    $self->status_message('gff_conversion: ' . timestr($gff_conversion_time, 'noc')) if $self->benchmark;
    
    #Read the .gff3 file containing the results from the iprscan and create Genome::InterproResult objects, which will be saved when UR::Context->commit is manually called or implicitly called before exit
    my $pre_results_parsing = Benchmark->new;
    my $gff = new Bio::Tools::GFF(-file => $converter_output, -gff_version => 3);
    my $status_file_handle = IO::File->new($status_file, "r");
    while (my $feature = $gff->next_feature()){
       if((defined $feature) and ($feature->primary_tag eq 'match_part')){
           load_part($feature, $build, $interpro_result_counter, $status_file_handle);
           $interpro_result_counter++;
           if ($interpro_result_counter % $commit_size == 0){
                UR::Context->commit; 
            }
       }
    }
    $status_file_handle->close; #cleanup the status_file_handle now while we're thinking about it

    my $post_results_parsing = Benchmark->new;
    my $results_parsing_time = timediff($post_results_parsing, $pre_results_parsing);
    $self->status_message('results parsing: ' . timestr($results_parsing_time, 'noc')) if $self->benchmark;
   
    #Cleanup tmp files and Filehandles
    my $pre_cleanup = Benchmark->new;
    #Finished successfully, cleanup all the tmp files
    unlink $iprscan_merged;
    unlink $converter_temp;
    for my $iprscan_path (keys %iprscan){
        unlink $iprscan{$iprscan_path};
    }
    for my $fasta_file (keys %fastas){
        unlink $fastas{$fasta_file};
    }
    #Finished successfully, delete the status file so we know that we've completed 
    unlink $status_file;

    #reset environment variables
    $ENV{'IPRSCAN_HOME'} = $old_iprscan_home;

    #Put STDOUT and STDERR back to their rightful locations
    close(STDOUT) or $self->error_message("Can't close STDOUT: $!");
    close(STDERR) or $self->error_message("Can't close STDERR: $!");
    open(STDERR, ">&OLDERR") or $self->error_message("Can't restore STDERR: $!");
    open(STDOUT, ">&OLDOUT") or $self->error_message("Can't restore STDOUT: $!");
    close(OLDOUT) or $self->error_message("Can't close OLDOUT: $!");
    close(OLDERR) or $self->error_message("Can't close OLDERR: $!");
    
    my $post_cleanup = Benchmark->new;
    my $cleanup_time = timediff($post_cleanup, $pre_cleanup);
    $self->status_message('cleanup: ' . timestr($cleanup_time, 'noc')) if $self->benchmark;
    
    my $total_finish = Benchmark->new;
    my $total_time = timediff($total_finish, $total_start);
    $self->status_message('Total: ' . timestr($total_time, 'noc')) if $self->benchmark;

    return 1;
}
1;

#Take a feature from the .gff version of the iprscan results along with the build and an arbitrary id and create the Genome::InterproResult object that will be written to the file based data source
#Also, write the transcript's data_directory and transcript_name to a file to a file so we can resume later if we crash
sub load_part
{
    my ($feature, $build, $interpro_id, $status_file) = @_;
    
    my $id    = ( $feature->get_tag_values("ID") )[0];
    my $parent_id; 
    eval { $parent_id = ( $feature->get_tag_values("Parent") )[0]; };
    my @go;
    eval { @go =  $feature->get_tag_values("Ontology_term"); };
    my $note;
    eval { $note  = ( $feature->get_tag_values("Note") )[0]; };
    my $name;
    eval { $name  = ( $feature->get_tag_values("Name") )[0]; };
    my $location = $feature->location;
    my $start = $location->start;
    my $stop = $location->end;
    
    
    my $transcript_name = $feature->seq_id;
    my @data_dirs = $build->determine_data_directory;
    my $transcript;
    for my $dir (@data_dirs){
        $transcript = Genome::Transcript->get(data_directory => $dir, 
                                              transcript_name => $transcript_name);
        last if $transcript;
    }
    die "Could not get transcript: $transcript_name from ". join(",", @data_dirs) unless $transcript; 
    
    #we're printing the status line in here because it's fast. This defies expectations and isn't clean. Sorry
    my $status_line = join("\t", $transcript->data_directory, $transcript_name) . "\n";
    $status_file->print($status_line);

    my $interpro_result = Genome::InterproResult->create(
        interpro_id => $interpro_id,
        chrom_name => $transcript->chrom_name,
        transcript_name => $transcript->transcript_name, 
        data_directory => $transcript->data_directory,
        start => $start,
        stop => $stop,
        rid => 0, #Copied directly from mg-load-ipro 
        setid => $id, 
        parent_id => $parent_id, 
        name => $name,
        interpro_note => $note,
    );
}

=pod

=head1 Name

Genome::Model::Tools::Annotate::ImportInterpro

=head1 Synopsis

Gets every transcript for a given build, runs them through Interpro, and creates Genome::InterproResult objects from the results

=head1 Usage

 in the shell:

     gmt annotate import-interpro --reference-transcripts NCBI-human.combined-annotation/54_36p

 in Perl:

     $success = Genome::Model::Tools::Annotate::ImportInterpro->execute(
         reference_transcripts => 'NCBI-human.combined-annotation/54_36p',
         interpro_version => '4.1', #default 4.5
         chunk_size => 40000, #default 25000
         log_file => mylog.txt, #default /dev/null
         tmp_dir =>  'myDir', #defualt /tmp
     );

=head1 Methods

=over

=item variant_file

A string containing the name and version number of the reference transcripts to use as input.  The format is:
name/version_number

=item 

=back

=head1 See Also

B<Genome::InterproResult>, 

=head1 Disclaimer

Copyright (C) 2010 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

 B<Jim Weible> I<jweible@genome.wustl.edu>

=cut


#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Tools/Annotate/ImportInterpro.pm $
#$Id: 
