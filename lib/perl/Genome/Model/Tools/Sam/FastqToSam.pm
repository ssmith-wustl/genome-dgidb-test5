package Genome::Model::Tools::Sam::FastqToSam;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;
use Sys::Hostname;
use Genome::Utility::AsyncFileSystem qw(on_each_line);

my $QUALITY_FORMAT_DEFAULT = "Standard";

class Genome::Model::Tools::Sam::FastqToSam {
    is  => 'Genome::Model::Tools::Sam',
    has => [
        fastq_file => {
            is  => 'String',
            doc => 'Input FastQ file',
        },
        sam_file => {
            is  => 'String',
            doc => 'Output Sam file',
        },
        quality_format => {
            is  => 'String',
            doc => "Quality format, default is $QUALITY_FORMAT_DEFAULT, choices are Standard, Solexa, Illumina. See Picard docs for more info.",
            is_optional => 1,
            default_value => $QUALITY_FORMAT_DEFAULT,
        },
    ],
};

sub help_brief {
    'Tool to convert Fastq to SAM file';
}

sub help_detail {
    return <<EOS
    Tool to convert Fastq files to Sam files.
EOS
}

sub execute {
	my $self = shift;

    my $picard_path = $self->picard_path;
    
    my $fastq_to_sam_cmd = sprintf("java  -jar %s/FastqToSam.jar QUALITY_FORMAT=%s SAMPLE_NAME='Hello there' FASTQ=%s OUTPUT=%s ", $self->picard_path, $self->quality_format, $self->fastq_file, $self->sam_file);

	Genome::Utility::FileSystem->shellcmd(
		cmd => $fastq_to_sam_cmd,
		input_files => [$self->fastq_file],
		output_files => [$self->sam_file],
	);

    # Picard leaves 2 lines of garbage at the top. This sed will strip all lines beginning with @, which are header lines
    my $sed_cmd = sprintf("sed -i '/^@/d' %s", $self->sam_file);
    Genome::Utility::FileSystem->shellcmd(
        cmd => $sed_cmd,
        input_files => [$self->sam_file],
        output_files => [$self->sam_file],
        skip_if_output_is_present   => 0,
    );

    return 1;
}

1;
