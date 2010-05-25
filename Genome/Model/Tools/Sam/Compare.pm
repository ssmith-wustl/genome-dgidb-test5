package Genome::Model::Tools::Sam::Compare;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;
use Sys::Hostname;
use Genome::Utility::AsyncFileSystem qw(on_each_line);

class Genome::Model::Tools::Sam::Compare {
    is  => 'Genome::Model::Tools::Sam',
    has => [
        file1 => {
            is  => 'String',
            doc => 'The first file in the comparison',
        },
        file2 => {
            is  => 'String',
            doc => 'The second file in the comparison',
        },
    ],
};

sub help_brief {
    'Tool to compare BAM or SAM files';
}

sub help_detail {
    return <<EOS
    Tool to compare BAM or SAM files.
EOS
}

sub execute {
    my $self = shift;

    my $picard_path = $self->picard_path;
    my $bam_cmp_cmd = sprintf("java  -cp %s/CompareSAMs.jar net.sf.picard.sam.CompareSAMs VALIDATION_STRINGENCY=SILENT %s %s ", $self->picard_path, $self->file1, $self->file2);
    print $bam_cmp_cmd, "\n\n\n\n";

    my $ret = 0;
    my $response;

    open(CMP, "$bam_cmp_cmd|");
    while (<CMP>) {
        $ret = 1 if (m/Differ\s*0$/); 
        $response .= $_;
    }
    close(CMP);

    print $response;

    return $ret;

}

1;
