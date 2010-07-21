package Genome::Model::Tools::Annotate::ImportInterpro::GenerateInterproResults;

use strict;
use warnings;
use Genome;
use IO::File;
use File::Temp;
use Bio::Tools::GFF;
use Benchmark qw(:all) ;

class Genome::Model::Tools::Annotate::ImportInterpro::GenerateInterproResults{
    is => 'Genome::Model::Tools::Annotate',
    has => [
        build => {
            is => 'Genome::Model::Build',
            is_input => 1,
            is_optional => 0,
        },
        benchmark => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
            is_input => 1,
            doc => 'if set, run times are displayed as status messages after certain steps are completed (x, y, z, etc)',
        },
        tmp_dir => { 
            is => 'Path',
            is_optional => 1,
            default => '/tmp',
            is_input => 1,
            doc => 'if set, temporary files for fasta generation, iprscan output, etc. are written to this directory.  Defaults to /tmp'
        },
        commit_size => {
            is => 'Number',
            is_input => 1,
            is_optional => 1,
            default => 100,
            doc => 'Number of Interpro results saved at a time.  Defaults to 100',
        },
        interpro_version => { 
            is => 'Number',
            is_input => 1,
            is_optional => 1,
            default => 4.5,
            doc => 'Version of Interpro used.  This option is currently nonfunctional  The default is 4.5',
        },
    ]
};


#TODO: Write me
sub help_synopsis {
    return <<EOS
TODO
EOS
}

#TODO: Write me
sub help_detail{ 
    return <<EOS
TODO
EOS
}

sub execute{
    my $self = shift;

    my $build = $self->build;
    my $tmp_dir = $self->tmp_dir;
    die "Could not get tmp directory $tmp_dir" unless $tmp_dir; #TODO: Sanity check this
    my $commit_size = $self->commit_size;
    die "Could not get commit-size $commit_size" unless $commit_size; 
    die "commit-size of $commit_size is invalid.  Must be greater than 1" if($commit_size < 1);
    my $iprscan_dir = '/gsc/scripts/pkg/bio/iprscan/iprscan-'.$self->interpro_version; #defaults to 4.5; 
    die "Could not find interpro version ".$self->interpro_version unless -d $iprscan_dir; 

    #Merge the tab delimited temp files containing the results from the iprscan(s) into a single tab delimimted file
    my $pre_iprscan_merger = Benchmark->new; 
    my %iprscan = $self->get_iprscan_results();
    my $iprscan_merged = File::Temp->new(UNLINK => 0,
                                         DIR => $tmp_dir,
                                         TEMPLATE => 'import-interpro_iprscan-merged-results_XXXXXX');
    my $iprscan_merged_path = $iprscan_merged->filename;
    for my $iprscan_path (keys %iprscan){
        my $fh = IO::File->new($iprscan_path, "r");
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
    my $interpro_result_counter = 1;
    my $pre_results_parsing = Benchmark->new;
    my $gff = new Bio::Tools::GFF(-file => $converter_output, -gff_version => 3);
    while (my $feature = $gff->next_feature()){
       if((defined $feature) and ($feature->primary_tag eq 'match_part')){
           load_part($feature, $build, $interpro_result_counter);
           $interpro_result_counter++;
           if ($interpro_result_counter % $commit_size == 0){
                UR::Context->commit; 
            }
       }
    }
    my $post_results_parsing = Benchmark->new;
    my $results_parsing_time = timediff($post_results_parsing, $pre_results_parsing);
    $self->status_message('results parsing: ' . timestr($results_parsing_time, 'noc')) if $self->benchmark;
 
}

sub get_iprscan_results{
    my $self = shift;
    my $tmp_dir = $self->tmp_dir;
    my %results;
    while (my $file = glob("$tmp_dir/import-interpro_iprscan-result_*")) {
        $results{$file}++;
    }
    return %results;
}

#Take a feature from the .gff version of the iprscan results along with the build and an arbitrary id and create the Genome::InterproResult object that will be written to the file based data source
#Also, write the transcript's data_directory and transcript_name to a file to a file so we can resume later if we crash
sub load_part
{
    my ($feature, $build, $interpro_id) = @_;
    
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
1;
