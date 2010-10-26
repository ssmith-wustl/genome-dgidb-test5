package Genome::Model::Tools::Soap::RunFastaToAgpScript;

use strict;
use warnings;

use Genome;

class  Genome::Model::Tools::Soap::RunFastaToAgpScript {
    is => 'Command',
    has => [
	scaffold_fasta_file => {
            is => 'Text',
            doc => 'Soap generated scaffold fasta file',
        },
        scaffold_size_cutoff => {
            is => 'Number',
            doc => 'Minimum scaffold size cutoff',
            is_optional => 1, #default value is 1
        },
        output_dir => {
            is => 'Text',
            doc => 'Directory to put output files',
        },
        output_file_prefix => {
            is => 'Text',
            doc => 'Output file prefix name',
            is_optional => 1, #otherwise defaults to 'PGA'
        },
	version => {
	    is => 'Number',
	    doc => 'Version of fasta2agp script to run',
	    valid_values => ['9.27.10']
	},
    ],
};

sub help_brief {
    'Tool to run fasta2agp script for soap PGA assemblies';
}

sub help_detail {
    return <<"EOS"
gmt soap run-fasta-to-agp-script --version 9.27.10 --scaffold_fasta_file /gscmnt/111/soap_assembly/SRA111_WUGC.scafSeq --scaffold-size-cutoff 100 --output-file-prefix SRA111_WUGC --output-dir  /gscmnt/111/soap_assembly/PGA
EOS
}

sub execute {
    my $self = shift;

    #get version of script
    my $script = $self->_full_path_to_script_version;

    #script output dir
    Genome::Utility::FileSystem->create_directory($self->output_dir) unless
	-d $self->output_dir;

    #validate input fasta file
    unless (-s $self->scaffold_fasta_file) {
	$self->error_message("Can't find file or file is zero size: ".$self->scaffold_fasta_file);
	return;
    }

    #run command
    my $command = 'perl '.$script.' -i '.$self->scaffold_fasta_file.' -o '.$self->output_dir;
    $command .= ' -size '.$self->scaffold_size_cutoff if $self->scaffold_size_cutoff;
    $command .= ' -name '.$self->output_file_prefix if $self->output_file_prefix;

    $self->status_message("Running fasta2agp with command: $command");

    system("$command"); #script has no return value

    return 1;
}

sub _full_path_to_script_version {
    my $self = shift;

    my $module_path = $self->class;
    $module_path =~ s/::/\//g;

    my $inc_dir = Genome::Utility::FileSystem->get_inc_directory_for_class($self->class);
    my $script = $inc_dir.$module_path.'/'.$self->version.'/'.$self->_script_name;

    unless (-x $script) {
	$self->error_message("Failed to find script: $script");
	return;
    }

    return $script;
}

sub _script_name {
    return 'fasta2agp.pl';
}

1;
