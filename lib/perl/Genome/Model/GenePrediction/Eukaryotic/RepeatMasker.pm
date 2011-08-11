package Genome::Model::GenePrediction::Eukaryotic::RepeatMasker;

# There seems to be a Genome::Model::Tools::RepeatMasker command tree that
# could replace this module, with some minor modifications.

use strict;
use warnings;

use Genome;
use Carp 'confess';
use Bio::SeqIO;
use File::Temp 'tempdir';
use File::chdir;
use File::Path 'rmtree';
use File::Basename;

# TODO: Probably shouldn't be using this patched version of bioperl
require '/gsc/scripts/opt/bacterial-bioperl/Bio/Tools/Run/RepeatMasker.pm';
require '/gsc/scripts/opt/bacterial-bioperl/Bio/Tools/RepeatMasker.pm';

class Genome::Model::GenePrediction::Eukaryotic::RepeatMasker {
    is => 'Command',
    has => [
        fasta_file => { 
            is  => 'FilePath',
            is_input => 1,
            doc => 'Fasta file to be masked',
        },
    ],
    has_optional => [
        masked_fasta => { 
            is => 'FilePath',
            is_input => 1,
            is_output => 1,
            doc => 'Masked sequence is placed in this file (fasta format)' 
        },
        ace_file_location => {
            is => 'FilePath',
            is_input => 1,
            is_output => 1,
            doc => 'If ace files are generated, they are concatenated and placed here',
        },
        repeat_library => {
            is => 'FilePath',
            is_input => 1,
            doc => 'Repeat library to pass to RepeatMasker', 
        },
	    species	=> {
            is  => 'Text',
            is_input => 1,
            doc => 'Species name',
		},
	    xsmall	=> {
            is  => 'Boolean',
            is_input => 1,
            default => 0,
            doc => 'If set, masked sequence is marked by lowercasing bases instead of using N',
		},
        temp_working_directory => {
            is => 'DirectoryPath',
            is_input => 1,
            doc => 'Temporary working files are written here',
        },
        skip_masking => {
            is => 'Boolean',
            is_input => 1,
            default => 0,
            doc => 'If set, masking is skipped',
        },
        make_ace => {
            is => 'Boolean',
            is_input => 1,
            default => 1,
            doc => 'If set, repeat masker will create an ace file for each sequence',
        },
    ], 
};

sub help_brief {
    return "RepeatMask the contents of the input file and write the result to the output file";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    my $self = shift;

    unless (-e $self->fasta_file and -s $self->fasta_file) {
        confess "File does not exist or has no size at " . $self->fasta_file;
    }

    unless (defined $self->repeat_library or defined $self->species) {
        confess "Either repeat library or species must be defined!";
    }
    elsif (defined $self->repeat_library and defined $self->species) {
        $self->warning_message("Both repeat library and species are specified, choosing repeat library!");
    }

    # Make sure the fasta file isn't tarred, and untar it if necessary
    # TODO Is this necessary?
    if ($self->fasta_file =~ /\.bz2$/) {
        my $unzipped_file = Genome::Sys->bunzip($self->fasta_file);
        confess "Could not unzip fasta file at " . $self->fasta_file unless defined $unzipped_file;
        $self->fasta_file($unzipped_file);
    }
    
    # Set defaults for masked fasta and ace file to input fasta path
    my $fasta_path = File::Spec->rel2abs($self->fasta_file);
    if (not defined $self->ace_file_location) {
        my $default_ace_file = "$fasta_path.repeat_masker.ace";
        $self->ace_file_location($default_ace_file);
        $self->status_message("Ace files being generated and location not given, default to $default_ace_file");
    }
    if (not defined $self->masked_fasta) {
        my ($fasta_name, $fasta_dir) = fileparse($self->fasta_file);
        my $masked_fh = File::Temp->new(
            TEMPLATE => "$fasta_name.repeat_masker_XXXXXX",
            DIR => $fasta_dir,
            CLEANUP => 0,
            UNLINK => 0,
        );
        chmod(0666, $masked_fh->filename);
        $self->masked_fasta($masked_fh->filename);
        $masked_fh->close;
        $self->status_message("Masked fasta file path not given, defaulting to " . $self->masked_fasta);
    }

    # Removing existing masked fasta output file
    if (-e $self->masked_fasta) {
        $self->warning_message("Removing existing file at " . $self->masked_fasta);
        unlink $self->masked_fasta;
    }

    # Even if this is being skipped, some sort of output is necessary... 
    if ($self->skip_masking) {
        $self->status_message("skip_masking flag is set, copying input fasta to masked fasta location");
        my $rv = Genome::Sys->copy_file($self->fasta_file, $self->masked_fasta);
        confess "Trouble executing copy of " . $self->fasta_file . " to " . $self->masked_fasta unless defined $rv and $rv;
        $self->status_message("Copy of input fasta at " . $self->fasta_file . " to masked fasta path at " .
            $self->masked_fasta . " successful, exiting!");
        return 1;
    }

    # Create a new temporary working directory, if necessary
    if (not defined $self->temp_working_directory) {
        my $temp_dir = tempdir(
            'RepeatMasker-XXXXXX',
            DIR => '/tmp/',
            CLEANUP => 0,
            UNLINK => 0,
        );
        chmod(0775, $temp_dir);
        $self->temp_working_directory($temp_dir);
        $self->status_message("Not given temp working directory, using $temp_dir");
    }

    my $input_fasta = Bio::SeqIO->new(
        -file => $self->fasta_file,
        -format => 'Fasta',
    );
    my $masked_fasta = Bio::SeqIO->new(
        -file => '>' . $self->masked_fasta,
        -format => 'Fasta',
    );

    # FIXME I (bdericks) had to patch this bioperl module to not fail if there is no repetitive sequence
    # in a sequence we pass in. This patch either needs to be submitted to BioPerl or a new wrapper for 
    # RepeatMasker be made for in house. I don't like relying on patched version of bioperl that isn't
    # tracked in any repo...
    my $masker;
    if (defined $self->repeat_library) {
    	$masker = Bio::Tools::Run::RepeatMasker->new(
            lib => $self->repeat_library, 
            xsmall => $self->xsmall, 
            verbose => 0,
            dir => $self->temp_working_directory,
            ace => $self->make_ace,
        );
    }
    elsif (defined $self->species) {
    	$masker = Bio::Tools::Run::RepeatMasker->new(
            species => $self->species, 
            xsmall => $self->xsmall, 
            verbose => 0,
            dir => $self->temp_working_directory,
            ace => $self->make_ace,
        );
    } 

    # FIXME This is the only way I know of to force this bioperl object to use the temp directory I want. If
    # this is not specified, the tool fails when it can't open an output file in the temp directory (because
    # the default temp directory doesn't have the permissions set appropriately...). If some bioperl guru
    # knows how to specify this during object creation and not have to violate class privacy like I am here,
    # please do.
    $masker->{_tmpdir} = $self->temp_working_directory;

    # FIXME RepeatMasker emits a warning when no repetitive sequence is found. I'd prefer to not have
    # this displayed, as this situation is expected and the warning message just clutters the logs.
    while (my $seq = $input_fasta->next_seq()) {
        local $CWD = $self->temp_working_directory; # More shenanigans to get repeat masker to not put temp dir in cwd,
                                                    # which could be a snapshot and cause problems
        $self->status_message("Working on sequence " . $seq->display_id);
        $masker->run($seq);
        my $masked_seq = $masker->masked_seq();
        $masked_seq = $seq unless defined $masked_seq; # If no masked sequence found, write original seq to file
        $masked_fasta->write_seq($masked_seq);

        # Repeat masker makes an ungodly number of files in the working directory, especially if checking a large
        # number of sequences. To prevent this from getting unwieldy, remove these files after each sequence
        $self->_cleanup_files;
    }   

    # Ace files generated by repeat masker are concatenated together
    if ($self->make_ace) {
        $self->status_message("Concatenating ace files generated by repeat masker in " . $self->temp_working_directory .
            " into ace file at " . $self->ace_file_location);
        unless ($self->_generate_ace_file) {
            $self->error_message("Could not create ace file!");
            confess $self->error_message;
        }
    }

    return 1;
}

sub _cleanup_files {
    my $self = shift;
    my $dir = $self->temp_working_directory;
    my @suffixes_to_axe = qw/ cat log out ref tbl /;
    for my $suffix (@suffixes_to_axe) {
        my @files = glob($dir . "/*.$suffix");
        unlink @files;
    }
    return 1;
}

sub _generate_ace_file {
    my $self = shift;
    my @ace_files = glob($self->temp_working_directory."/*ace");
    $self->status_message("Ace file $ace_files[0]");

    $self->status_message("Fasta " . $self->masked_fasta);
	my ( $masked_file_name, $dir ) = fileparse($self->masked_fasta);
	my @masked_file_name = split(/repeat_masker/, $masked_file_name);

    #local $CWD = $self->temp_working_directory;

	my $new_ace_file_name = $self->ace_file_location;
	$self->status_message("Ace file name: ". $new_ace_file_name);
	my $ace_file_fh = IO::File->new($new_ace_file_name, "a");
	$self->error_message("Could not get handle for ace file($ace_file_fh): $!") and return unless $ace_file_fh;

    foreach my $ace_file (@ace_files) {
		my @file_name = split(/\./, $ace_file);
		my $masked_fh = IO::File->new($file_name[0], "r");
		$self->error_message("Could not get handle for masked file($file_name[0]): $!") and return 0 unless $masked_fh;
		undef my $contig_name;
		while (my $line = $masked_fh->getline) {
			chomp $line;
			if ($line =~ m/^>(.*)/) {
		  		$contig_name = $1;
				$self->status_message("contig_name: ". $contig_name);
				last;
			}
		}
		$masked_fh->close;

		my $ace_fh = IO::File->new($ace_file, "r");
		$self->error_message("Could not get handle for ace file($ace_file): $!") and return unless $ace_fh;

		undef my $line_count;
		$line_count = 0;
		while (my $line = $ace_fh->getline) {
			$ace_file_fh->print("Sequence $contig_name\n") if ($line_count == 0);
            $line = ~s/\s+(\+|\-)\s+/ /;
			$ace_file_fh->print($line);
			$line_count++;
		}
		$ace_file_fh->print("\n");
	}
    $ace_file_fh->close;
    return 1;
}

1;
