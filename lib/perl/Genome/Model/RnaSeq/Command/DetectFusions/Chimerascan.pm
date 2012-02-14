package Genome::Model::RnaSeq::Command::DetectFusions::Chimerascan;
use strict;
use warnings;
use Genome;

# this is the one from tophat
# my $DEFAULT_LSF_RESOURCE = "-R 'select[model!=Opteron250 && type==LINUX64 && mem>64000 && tmp>150000] span[hosts=1] rusage[tmp=150000, mem=64000]' -M 64000000 -n 4"; 

# this is from Chris Miller: check with Chris Maher
my $DEFAULT_LSF_RESOURCE = "-R 'select[type==LINUX64 && mem>16000] span[hosts=1] rusage[mem=16000]' -M 16000000 -n 8";

# Notes from Chris Miller:
# bsub -oo err.log -q long 
# -M 16000000 -R 'select[type==LINUX64 && mem>16000] span[hosts=1] rusage[mem=16000]' -n 8 
# -J chimera -oo outputdir/chimera.err 
# "python /gsc/bin/chimerascan_run.py -v -p 8 
#   /gscmnt/sata921/info/medseq/cmiller/annotations/chimeraScanIndex/
#   $fastq1 $fastq2 $outputdir"

class Genome::Model::RnaSeq::Command::DetectFusions::Chimerascan {
    is => 'Command::V2',
    has => [
        # params
        use_version => {
            is => 'Text',
            is_param => 1,
            is_optional => 1,
            doc => 'the version of chimerascan to run (not supported yet, runs the default)'
        },
        params => {
            is => 'Text',
            is_optional => 1,
            is_param => 1,
            doc => 'parameters for chimerascan (-v and -p are set automatically, defaults to nothing)'
        },

        # inputs
        fastq1 => {
            is => 'FilesystemPath',
            is_input => 1,
            shell_args_position => 1,
            doc => 'input fastq1',
        },
        fastq2 => {
            is => 'FilesystemPath',
            is_input => 1,
            shell_args_position => 2,
            doc => 'input fastq2',
        },
        
        reference_annotation => { 
            is => 'Genome::Model::Build::ImportedAnnotation', 
            id_by => 'reference_annotation_id',
            shell_args_position => 3,
            # is_input => 1, ## this must be declared specifically below
            doc => 'the data set of reference annotation (build ID/name)',
        },
        
        # TODO: when workflows will take objects, remove this, and un-commend is_input above..
        reference_annotation_id => {
            is => 'Integer',
            is_input => 1,
            shell_args_position => 3,
            implied_by => 'reference_annotation',
            doc => 'the ID for the reference annotation data set to be used',
        },

        output_directory => {
            is => 'FilsystemPath',
            is_input => 1,
            is_output => 1,
            shell_args_position => 4,
            doc => 'the directory into which results are stored'
        },

        lsf_resource => { 
            default_value => $DEFAULT_LSF_RESOURCE, 
            is_param => 1,
            is_optional => 1,
            doc => 'default LSF resource expectations',
        },

    ],
    doc => 'run the chimerascan transcript fusion detector',
};

sub execute {
    my $self = shift;
    
    my $cmd_path = $self->path_for_version($self->version);
    unless ($cmd_path) {
        die $self->error_message("Failed to find a path for chimerascan for version " . $self->version . "!");
    }

    my $annotation_build = $self->annotation_build;
    unless ($annotation_build) {
        die $self->error_message("No annotation build found!  ID was " . $self->annotation_build);
    }

    my $index_dir = $self->resolve_index_dir_for_annotation_build($annotation_build);

    my $fastq1 = $self->fastq1;
    my $fastq2 = $self->fastq2;
    my $params = $self->params;
    my $output_directory = $self->output_directory;
   
    my $n_threads = 8; # TODO: switch to checking the environment variables set by lsf

    my $cmd = "echo python $cmd_path -v -p $n_threads $params $index_dir $fastq1 $fastq2 $output_directory >$output_directory/testout.txt";
   
    Genome::Sys->shell_cmd(
        cmd => $cmd,
        input_files => [$fastq1, $fastq2, $index_dir, $output_directory],
    );

    return 1;
}

sub path_for_version {
    my ($self,$version) = @_;
    # TODO: package chimerascan, and switch to versioned executables
    my $path = '/gsc/bin/chimerascan_run.py';
    warn "ignoring version, running default $path";
    return $path;
}

sub resolve_index_dir_for_annotation_build {
    my ($self, $annotation_build) = @_;
    # TODO: create a software result for the index
    my $path = '/gscmnt/sata921/info/medseq/cmiller/annotations/chimeraScanIndex/';
    warn "hard-coded index path $path";
    return $path;
}

sub help_synopsis {
    return <<EOS
 genome model rna-seq detect-fusions chimerascan index_dir/ f1.fastq f2.fast2 output_dir/
 
 genome model rna-seq detect-fusions chimerascan index_dir/ f1.fastq f2.fast2 output_dir/ --use-version 1.2.3 --params "-a -b -c"
 
EOS
}

sub help_detail {
    return <<EOS
Run the chimerascan gene fusion detector.

It is used by the RNASeq pipeline to perform fusion detection when the fustion detection strategy is set to something like:
 'chimera-scan 1.2.3'

EOS
}

1;

__END__

# code below will extend this step to store chimerascan results in a shortcuttable/reusable way

# hypothetical, unused until we get SoftwareResults and shortcutting in place
my $SOFTWARE_RESULT_CLASS = 'Genome::Transcript::Variant::Fusion::Detector::Result'; 

sub execute {
    my $self = shift;

    my $result = $self->_generate_software_result;
    unless($result) {
        $self->error_message('Failed to generate alignment.');
        die $self->error_message;
    }

    $self->_link_build_to_result($result);
    $self->status_message('Generated alignment.');
    return 1;
}

sub shortcut {
    my $self = shift;

    # This is a lightweight version of execute which attempts to find pre-existing
    # results.  The workflow system will try this first, then the real execute().

    #try to get using the lock in order to wait here in shortcut if another process is creating this alignment result
    my $result = $self->build->_get_software_result_with_lock;
    unless($result) {
        $self->status_message('No existing alignment found.');
        return;
    }

    $self->_link_build_to_result($result);
    $self->status_message('Using existing alignment ' . $result->__display_name__);
    return 1;
}

sub _link_build_to_result {
    my $self = shift;
    my $alignment = shift;

    my $link = $alignment->add_user(user => $self->build, label => 'uses');
    if ($link) {
        $self->status_message("Linked alignment " . $alignment->id . " to the build");
    }
    else {
        $self->error_message(
            "Failed to link the build to the alignment "
            . $alignment->__display_name__
            . "!"
        );
        die $self->error_message;
    }

    Genome::Sys->create_symlink($alignment->output_dir, $self->build->accumulated_alignments_directory);

    return 1;
}

sub software_result {
    my $self = shift;

    my @u = Genome::SoftwareResult::User->get(user_id => $self->build_id);
    my $alignment_class = $SOFTWARE_RESULT_CLASS->_resolve_subclass_name_for_aligner_name($self->processing_profile->read_aligner_name);
    my $alignment = join('::', 'Genome::InstrumentData::AlignmentResult', $alignment_class)->get([map($_->software_result_id, @u)]);
    return $alignment;
}

sub _generate_software_result {
    my $self = shift;
    return $self->_fetch_software_result('get_or_create');
}

sub _get_software_result_with_lock {
    my $self = shift;
    return $self->_fetch_software_result('get_with_lock');
}


sub _fetch_software_result {
    my $self = shift;
    my $mode = shift;

    my @instrument_data_inputs = $self->instrument_data_inputs;
    my ($params) = $self->model->params_for_alignment(@instrument_data_inputs);

    my $alignment_class = Genome::InstrumentData::AlignmentResult->_resolve_subclass_name_for_aligner_name($self->model->read_aligner_name);
    my $alignment = join('::', 'Genome::InstrumentData::AlignmentResult', $alignment_class)->$mode(
        %$params,
    );

    return $alignment;
}
1;
