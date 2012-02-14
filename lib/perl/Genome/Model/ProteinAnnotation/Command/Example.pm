package Genome::Model::ProteinAnnotation::Command::Example;

use strict;
use warnings;
use Genome;

class Genome::Model::ProteinAnnotation::Command::Example {
    is  => 'Genome::Model::ProteinAnnotation::Command::Annotator',
    has => [
        use_version => { 
            is => 'Text', 
            is_param => 1,
            doc => 'the version of the tool to use',
        },
        params => {
            is => 'Text',
            is_optional => 1,
            is_param => 1,
            doc => 'params to pass to the tool',
        },
        input_fasta => { 
            is => 'FilesystemPath',
            is_input => 1,
            doc => 'input file of predicted gene sequences',            
        },
        output_dir => { 
            is => 'FilesystemPath', 
            is_input => 1, 
            is_output => 1, 
            doc => 'directory containing raw output and dumped features',
        },
        output_features => { 
            is => 'ARRAY',  
            is_output => 1,
            doc => 'array of Bio::Seq::Feature objects', 
        },

        lsf_resource => {
            is_param => 1,
            is_optional => 1,
            default => "-R 'select[mem=8192,type==LINUX64] rusage[mem=8192,tmp=1024]' -M 8192000",
            doc => 'override LSF resource requirements'
        },
        lsf_queue => {
            is_param => 1,
            is_optional => 1,
            default => 'apipe',
            doc => 'override the default queue for jobs'
        },
    ],
};

sub requires_chunking { 0 }

sub help_synopsis {
    return <<"EOS"
genome model protein-annotation example --use-version 1.2.3 --params "-a -b -n 10" --input-fasta mygenes.fa --output-dir /my/dir

genome model protein-annotation example -i mygenes.fa -o /my/dir -u 1.2.3

EOS
}

sub help_detail {
    return <<"EOS"
The example annotator does nothing, and is only used for testing.  Copy this module, rename the class, and implemente execute() to do real work!
EOS
}

sub execute {
    my $self = shift;

    my $use_version = $self->use_version;
    my $params = $self->params || '';
    my $input_fasta = $self->input_fasta;
    my $output_dir = $self->output_dir;
    
    # change this to actually run the annotation tool correctly
    my $cmd = "echo exampleapp$use_version $params $input_fasta >$output_dir/dummy-output";
    
    Genome::Sys->dump_status_messages(1);
    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$input_fasta],
        output_files => ["$output_dir/dummy-output"],
    );

    $self->status_message("processing features...");
    # put code here to make Bio::Seq::Feature objects from the data and put them in the @features array
    # we make one dummy oone here for testing..
    my @features = ();
    my $feature = Bio::SeqFeature::Generic->new(-display_name => "DUMY");
    $feature->add_tag_value('psort_localization', "some-class");
    $feature->add_tag_value('psort_score', 123);
    push @features, $feature;

    $self->status_message("dumping features objects to the output directory...");
    Genome::Sys->write_file($output_dir . '/feature-dump.dat', Data::Dumper::Dumper(\@features));
    $self->output_features(\@features);

    $self->status_message("processing complete");
    return 1;
}

1;

