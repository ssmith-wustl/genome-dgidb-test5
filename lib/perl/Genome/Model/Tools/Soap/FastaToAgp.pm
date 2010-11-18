package Genome::Model::Tools::Soap::FastaToAgp;

use strict;
use warnings;

use Genome;
use File::Basename;

class  Genome::Model::Tools::Soap::FastaToAgp {
    is => 'Command',
    has => [
        scaffold_size_cutoff => {
            is => 'Integer',
            doc => 'Minimum scaffold size cutoff',
        },
	version => {
	    is => 'String',
	    doc => 'Version of fasta2agp script to run',
	    valid_values => ['9.27.10'],
	},
	assembly_directory => {
	    is => 'Text',
	    doc => 'Assembly directory',
	},
    ],
    has_optional => [
        output_dir => {
            is => 'Text',
            doc => 'Directory to put output files',
        },
	scaffold_fasta_file => {
            is => 'Text',
            doc => 'Soap generated scaffold fasta file, if not specified, tool will derive it',
	},
	file_prefix => {
            is => 'Text',
            doc => 'Output file prefix name, if not specified, tool will derive it from soap output file prefixes',
        },
    ],
    has_optional_transient => [
	_output_dir          => { is => 'Text', },
	_scaffold_fasta_file => { is => 'Text', },
	_file_prefix         => { is => 'Text', },
    ],
};

sub help_brief {
    'Tool to run fasta2agp script for soap PGA assemblies';
}

sub help_detail {
    return <<"EOS"
gmt soap fasta-to-agp --version 9.27.10 --scaffold_fasta_file /gscmnt/111/soap_assembly/SRA111_WUGC.scafSeq --scaffold-size-cutoff 100 --file-prefix SRA111_WUGC --output-dir  /gscmnt/111/soap_assembly/PGA
EOS
}

sub execute {
    my $self = shift;

    #derive and set transient params
    unless ( $self->_validate_and_set_params ) {
	$self->error_message("Failed to set tools transient params");
	return;
    }

    #get version of script
    my $script = $self->_full_path_to_version_script;

    #create script command string
    my $command = 'perl '.$script.' -i '.$self->_scaffold_fasta_file.' -o '.$self->_output_dir;
    $command .= ' -size '.$self->scaffold_size_cutoff if $self->scaffold_size_cutoff;
    $command .= ' -name '.$self->_file_prefix;# if $self->output_file_prefix;

    $self->status_message("Running fasta2agp with command: $command");

    system("$command"); #script has no return value

    #check for expected output files
    unless ( $self->_check_output_files ) {
	$self->error_message("Failed to create all expected output files");
	return;
    }

    return 1;
}

sub _full_path_to_version_script {
    my $self = shift;

    my $module_path = $self->class;
    $module_path =~ s/::/\//g;

    my $inc_dir = Genome::Utility::FileSystem->get_inc_directory_for_class($self->class);
    my $script = $inc_dir.$module_path.'/'.$self->version.'/'.$self->_script_name;

    unless ( -x $script ) {
	$self->error_message("Failed to find script: $script");
	return;
    }

    return $script;
}

sub _script_name {
    return 'fasta2agp.pl';
}

sub _validate_and_set_params {
    my $self = shift;

    for my $param ( qw/ scaffold_fasta_file file_prefix output_dir / ) {
	my $method = '_set_' . $param .'_param';
	unless ( $self->$method ) {
	    $self->error_message("Failed to set and validate tool param: $param");
	    return;
	}
    }

    return 1;
}

sub _set_scaffold_fasta_file_param {
    my $self = shift;

    my @files = glob( $self->assembly_directory."/*scafSeq" );
    
    unless ( @files ) {
	$self->error_message("Did not find any *scafSeq files in assembly directory: ".$self->assembly_directory);
	return;
    }

    unless ( scalar @files == 1 ) {
	$self->error_message("Expected 1 *scafSeq file in assembly directory but found " . scalar @files .
			     "\nUnable to set scaffold_fasta_file param for tool");
	return;
    }

    $self->_scaffold_fasta_file( $files[0] );

    return 1;
}

sub _set_file_prefix_param {
    my $self = shift;

    my @files = glob( $self->assembly_directory."/*scafSeq" );

    unless ( @files ) {
	$self->error_message("Did not find any *scafSeq files in assembly directory: ".$self->assembly_directory);
	return;
    }
    
    my ($file_prefix) = $files[0] =~ /^(\S+)\.scafSeq$/;
    $file_prefix = basename ( $file_prefix );

    unless ( $file_prefix ) {
	$self->error_message("Failed to derive file prefix from scafSeq file, expected SRA1234 from name like SRA1234.scafSeq");
	return;
    }

    $self->_file_prefix( $file_prefix );
    
    return 1;
}

sub _set_output_dir_param {
    my $self = shift;

    #output dir = input assembly dir unless directed else where by
    my $output_dir = ( $self->output_dir ) ? $self->output_dir : $self->assembly_directory;

    Genome::Utility::FileSystem->create_directory( $output_dir ) unless
	-d $output_dir;

    $self->_output_dir( $output_dir );

    return 1;
}

sub _check_output_files {
    my $self = shift;

    for my $file_ext ( qw/ contigs.fa agp scaffolds.fa / ) {
	my $file = $self->_output_dir.'/'.$self->_file_prefix.'.'.$file_ext;
	unless ( -e $file ) {
	    $self->error_message("Failed to find output file: $file");
	    return;
	}
    }
    return 1;
}

1;
