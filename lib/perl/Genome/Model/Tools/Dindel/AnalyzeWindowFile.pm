package Genome::Model::Tools::Dindel::AnalyzeWindowFile;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Dindel::AnalyzeWindowFile {
    is => 'Command',
    has => [
    window_file=> {
        is=>'String',
        is_input=>1,
    },
    library_metrics_file=>{
        is=>'String',
        is_input=>1,
        doc=>'from step one... getCigarIndels',
    },
    bam_file=> {
        is=>'String',
        is_input=>1,
    },
    output_prefix=> {
        is=>'String',
        is_input=>1,
        is_output=>1,
    },
    ref_fasta=> {
        is=>'String',
        is_input=>1,
    },
    ],
};

sub help_brief {
    'Run getCIGARindels'
}

sub help_synopsis {
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
EOS
}


sub execute {
    my $self = shift;
    my $dindel_location = "/gscmnt/gc2146/info/medseq/dindel/binaries/dindel-1.01-linux-64bit";
    my $ref = $self->ref_fasta;
    my $output = $self->output_prefix;
    my $input = $self->window_file;
    my $lib_file = $self->library_metrics_file;
    my $bam = $self->bam_file;
    my $cmd = "$dindel_location --analysis indels --doDiploid --bamFile $bam --varFile $input --outputFile $output --ref $ref --libFile $lib_file";
    return Genome::Sys->shellcmd(cmd=>$cmd);
}

1;
