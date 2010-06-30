package Genome::Model::Tools::DetectVariants;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants {
    is => 'Command',
    has_constant => [
        detect_snvs => {
            is => 'Boolean',
            value => '0',
            doc => 'Indicates whether this variant detector should detect SNVs',
        },
        detect_indels => {
            is => 'Boolean',
            value => '0',
            doc => 'Indicates whether this variant detector should detect small indels',
        },
        detect_svs => {
            is => 'Boolean',
            value => '0',
            doc => 'Indicates whether this variant detector should detect structural variations',
        },
    ],
    has_optional => [
        capture_set_input => {
            is => 'Text',
            doc => 'Location of the file containing the regions of interest (if present, only variants in the set will be reported)',
            is_input => 1,
        },
        snv_params => {
            is => 'Text',
            doc => 'Parameters to pass through to SNV detection',
            is_input => 1,
        },
        indel_params => {
            is => 'Text',
            doc => 'Parameters to pass through to small indel detection',
            is_input => 1,
        },
        sv_params => {
            is => 'Text',
            doc => 'Parameters to pass through to structural variation detection',
            is_input => 1,
        },
        version => {
            is_input => 1,
            is => 'Version',
            doc => 'The version of the variant detector to use.',
        },
        output_directory => {
            is => 'Text',
            doc => 'Location to save to the detector-specific files generated in the course of running',
            is_input => 1,
            is_output => 1,
        },
    ],
    has => [
        aligned_reads_input => {
            is => 'Text',
            doc => 'Location of the aligned reads input file',
            shell_args_position => '1',
            is_input => 1,
        },
        reference_sequence_input => {
            is => 'Text',
            doc => 'Location of the reference sequence file',
            is_input => 1,
        },
        
        _snv_base_name => {
            is => 'Text',
            default_value => 'snps_all_sequences',
            is_input => 1,
        },
        snv_output => {
            calculate_from => ['_snv_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_snv_base_name); },
            doc => "Where the SNV output should be once all work has been done",
            is_output => 1,
        },
        _snv_staging_output => {
            calculate_from => ['_temp_staging_directory', '_snv_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_snv_base_name); },
            doc => 'Where the SNV output should be generated (It will be copied to the snv_output in _promote_staged_data().)',
        },
        _indel_base_name => {
            is => 'Text',
            default_value => 'indels_all_sequences',
            is_input => 1,
        },
        indel_output => {
            calculate_from => ['_indel_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_indel_base_name); },
            is_output => 1,
        },
        _indel_staging_output => {
            calculate_from => ['_temp_staging_directory', '_indel_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_indel_base_name); },
        },
        _sv_base_name => {
            is => 'Text',
            default_value => 'svs_all_sequences',
            is_input => 1,
        },
        sv_output => {
            calculate_from => ['_sv_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_sv_base_name); },
            is_output => 1,
        },
        _sv_staging_output => {
            calculate_from => ['_temp_staging_directory', '_sv_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_sv_base_name); },
        },
        _filtered_snv_base_name => {
            is => 'Text',
            default_value => 'snps_all_sequences.filtered',
            is_input => 1,
        },
        filtered_snv_output => {
            calculate_from => ['_filtered_snv_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_filtered_snv_base_name); },
            is_output => 1,
        },
        _filtered_snv_staging_output => {
            calculate_from => ['_temp_staging_directory', '_filtered_snv_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_filtered_snv_base_name); },
        },
        _filtered_indel_base_name => {
            is => 'Text',
            default_value => 'indels_all_sequences.filtered',
            is_input => 1,
        },
        filtered_indel_output => {
            calculate_from => ['_filtered_indel_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_filtered_indel_base_name); },
            is_output => 1,
        },
        _filtered_indel_staging_output => {
            calculate_from => ['_temp_staging_directory', '_filtered_indel_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_filtered_indel_base_name); },
        },
        _filtered_sv_base_name => {
            is => 'Text',
            default_value => 'svs_all_sequences.filtered',
            is_input => 1,
        },
        filtered_sv_output => {
            calculate_from => ['_filtered_sv_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_filtered_sv_base_name); },
            is_output => 1,
        },
        _filtered_sv_staging_output => {
            calculate_from => ['_temp_staging_directory', '_filtered_sv_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_filtered_sv_base_name); },
        },
    ],
    has_transient_optional => [
        _temp_staging_directory  => {
            is => 'Text',
            doc => 'A directory to use for staging the data before putting it in the output_directory--all data here will be copied in _promote_staged_data().',
        },
        _temp_scratch_directory  => {
            is=>'Text',
            doc=>'Temp scratch directory',
        },
    ],
};

sub help_brief {
    "A selection of variant detectors.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants ...
EOS
}

sub help_detail {
    return <<EOS 
Tools to run variant detectors with a common API and output their results in a standard format.
EOS
}

sub execute {
    my $self = shift;
    
    if($self->_should_skip_execution) {
        $self->status_message('All processes skipped.');
        return 1;
    }
    
    unless($self->_verify_inputs) {
        $self->error_message('Failed to verify inputs.');
        return;
    }
    
    unless($self->_create_directories) {
        $self->error_message('Failed to create directories.');
        return;
    }
    
    unless($self->_detect_variants) {
        $self->error_message('Failed in main execution logic.');
        return;
    }
    
#    unless($self->_generate_standard_files) {
#        $self->error_message('Failed to generate standard files from detector-specific files');
#        return;
#    }
    
    unless($self->_promote_staged_data) {
        $self->error_message('Failed to promote staged data.');
        return;
    }
    
    return 1;
}

sub _should_skip_execution {
    my $self = shift;
    
    if(not ($self->detect_snvs or $self->detect_indels or $self->detect_svs)) {
        $self->status_message('No variant types were selected for detection.');
        return 1;
    }
    
    return 0;
}

sub _verify_inputs {
    my $self = shift;
    
    my $ref_seq_file = $self->reference_sequence_input;
    unless(Genome::Utility::FileSystem->check_for_path_existence($ref_seq_file)) {
        $self->error_message("reference sequence input $ref_seq_file does not exist");
        return;
    }

    my $aligned_reads_file = $self->aligned_reads_input;
    unless(Genome::Utility::FileSystem->check_for_path_existence($aligned_reads_file)) {
        $self->error_message("aligned reads input $aligned_reads_file was not found.");
        return;
    }
    
    return 1;
}

sub _create_directories {
    my $self = shift;
    
    my $output_directory = $self->output_directory;
    unless (-d $output_directory) {
        eval {
            Genome::Utility::FileSystem->create_directory($output_directory);
        };
        
        if($@) {
            $self->error_message($@);
            return;
        }

        $self->status_message("Created directory: $output_directory");
        chmod 02775, $output_directory;
    }
    
    $self->_temp_staging_directory(Genome::Utility::FileSystem->create_temp_directory);
    $self->_temp_scratch_directory(Genome::Utility::FileSystem->create_temp_directory);
    
    return 1;
}

sub _detect_variants {
    my $self = shift;
    
    die('To implement a variant detector to this API, the _detect_variants method needs to be implemented.');
}

sub _generate_standard_files {
    my $self = shift;
    
    my $class = ref $self || $self;
    my @words = split('::', $class);
    
    unless(scalar(@words) > 2 and $words[0] eq 'Genome') {
        die('Could not determine detector class automatically.  Please implement _generate_standard_files in the subclass.');
    }
    
    my $detector = $words[-1];
}

sub _promote_staged_data {
    my $self = shift;

    my $staging_dir = $self->_temp_staging_directory;
    my $output_dir  = $self->output_directory;

    $self->status_message("Now de-staging data from $staging_dir into $output_dir"); 

    my $call = sprintf("rsync -avz %s/* %s", $staging_dir, $output_dir);

    my $rv = system($call);
    $self->status_message("Running Rsync: $call");

    unless ($rv == 0) {
        $self->error_message("Did not get a valid return from rsync, rv was $rv for call $call.  Cleaning up and bailing out");
        rmpath($output_dir);
        die $self->error_message;
    }

    chmod 02775, $output_dir;
    for my $subdir (grep { -d $_  } glob("$output_dir/*")) {
        chmod 02775, $subdir;
    }

    $self->status_message("Files in $output_dir: \n" . join "\n", glob($output_dir . "/*"));

    return $output_dir;
}

1;
