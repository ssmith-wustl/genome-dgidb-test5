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
            doc => 'Version of Interpro used.  The default is 4.5',
        },
        benchmark => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
            is_input => 1,
            doc => 'if set, run times are displayed as status messages after certain steps are completed (x, y, z, etc)',
        },
    ],
};

#TODO: Useful help synopsis here
sub help_synopsis {
    return <<EOS
Insert useful syntax here
EOS
}

#TODO: Useful help detail here
sub help_detail{
    return <<EOS
Do something helpful
EOS
}

sub execute {
    $DB::single = 1; #TODO: Remove Me!
    my $self = shift;
   
    my $total_start = Benchmark->new;
   
    my ($model_name, $build_version) = split("/", $self->reference_transcripts);
    my $model = Genome::Model->get(name => $model_name);
    die "Could not get model $model_name" unless $model;
    my $build = $model->build_by_version($build_version);
    die "Could not get imported annotation build version $build_version" unless $build;
    my $transcript_iterator = $build->transcript_iterator;
    die "Could not get iterator" unless $transcript_iterator;
   
    my $fasta_temp = File::Temp->new;
    my $fasta = $fasta_temp->filename; 
    my $fasta_writer = new Bio::SeqIO(-file => ">$fasta", -format => 'fasta');
    die "Could not get fasta writer" unless $fasta_writer;

    my $pre_fasta_generation = Benchmark->new;
    
    my $transcript_counter = 0; 
    while (my $transcript = $transcript_iterator->next){
        my $protein = $transcript->protein;
        next unless $protein;
        my $amino_acid_seq = $protein->amino_acid_seq;
        my $bio_seq = Bio::Seq->new(-display_id => $transcript->transcript_name,
                                    -seq => $amino_acid_seq);
        $fasta_writer->write_seq($bio_seq);
        $transcript_counter++; 
        last if ($transcript_counter % 25000 == 0 ); 
    }

    my $post_fasta_generation = Benchmark->new;
    my $fasta_generation_time = timediff($post_fasta_generation, $pre_fasta_generation);
    $self->status_message('.fasta generation: ' . timestr($fasta_generation_time, 'noc')) if $self->benchmark;
    my $pre_iprscan = Benchmark->new;

    #TODO: Make sure STDOUT and STDERR are redirected before submitting to the blades.  It could crash LSF if you don't
    my $iprscan_temp = File::Temp->new;
    my $iprscan_output = $iprscan_temp->filename; 
    
    Genome::Utility::FileSystem->shellcmd(cmd => 'iprscan -cli -i ' . $fasta . ' -o ' . $iprscan_output . ' -seqtype p -appl hmmpfam -iprlookup -goterms -verbose -format raw',) or die "iprscan failed: $!"; #TODO: max number of sequences in the fasta is 50,000 as of 6/9/2010. Human is >60,000.  Find a solution

    my $post_iprscan = Benchmark->new;
    my $iprscan_time = timediff($post_iprscan, $pre_iprscan);
    $self->status_message('iprscan: ' . timestr($iprscan_time, 'noc')) if $self->benchmark;

    my $pre_gff_conversion = Benchmark->new;
    $ENV{'IPRSCAN_HOME'} = '/gscmnt/temp110/info/annotation/Interproscan/iprscan16.1/iprscan';
    my $converter_dir = '/gscmnt/temp110/info/annotation/Interproscan/iprscan16.1/iprscan';
    my $converter_lib = '/lib';
    my $converter_cmd = '/bin/converter.pl';
    my $converter_temp = File::Temp->new;
    my $converter_output = $converter_temp->filename;
    Genome::Utility::FileSystem->shellcmd(cmd => "perl -I " . $converter_dir.$converter_lib . " " . $converter_dir.$converter_cmd . " --input " . $iprscan_output . " --output " . $converter_output . " --format gff3",) or die "gff conversion failed: $!";
    my $post_gff_conversion = Benchmark->new;
    my $gff_conversion_time = timediff($post_gff_conversion, $pre_gff_conversion);
    $self->status_message('gff_conversion: ' . timestr($gff_conversion_time, 'noc')) if $self->benchmark;
    
    my $pre_results_parsing = Benchmark->new;
    my $gff = new Bio::Tools::GFF(-file => $converter_output, -gff_version => 3);
    my $interpro_result_counter = 1;
    while (my $feature = $gff->next_feature()){
       if((defined $feature) and ($feature->primary_tag eq 'match_part')){
           load_part($feature, $build, $interpro_result_counter);
           $interpro_result_counter++;
       }
    }
    my $post_results_parsing = Benchmark->new;
    my $results_parsing_time = timediff($post_results_parsing, $pre_results_parsing);
    $self->status_message('results parsing: ' . timestr($results_parsing_time, 'noc')) if $self->benchmark;
    
    my $total_finish = Benchmark->new;
    my $total_time = timediff($total_finish, $total_start);
    $self->status_message('Total: ' . timestr($total_time, 'noc')) if $self->benchmark;
    
    return 1;
}
1;

sub load_part
{
    my ($feature, $build, $interpro_id) = @_;
    
    my $id    = ( $feature->get_tag_values("ID") )[0];
    my $parid; 
    eval { $parid = ( $feature->get_tag_values("Parent") )[0]; };
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
                                              transcript_name => $transcript_name );
        last if $transcript;
    }
    die "Could not get transcript!" unless $transcript; 

    my $interpro_result = Genome::InterproResult->create(
        interpro_id => $interpro_id,
        chrom_name => $transcript->chrom_name,
        transcript_name => $transcript->transcript_name, 
        data_directory => $transcript->data_directory,
        start => $start,
        stop => $stop,
        rid => 0, #Copied directly from mg-load-ipro #TODO: What is this? rename
        setid => $id, #TODO: What is this? rename
        parid => $parid, #TODO: What is this? rename
        name => $name,
        inote => $note,
    );
}

#TODO: Do some pod documentation
