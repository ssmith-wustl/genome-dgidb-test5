package Genome::Model::Tools::Validation::AnnotationToAssemblyInput;

use strict;
use warnings;

use Genome;
use Genome::Utility::FileSystem;

class Genome::Model::Tools::Validation::AnnotationToAssemblyInput {
    is => 'Command',

    has => [
    annotation_file    => { 
        is => 'String', 
        doc => 'annotation output or annotator input file',
    },
    output_file => { 
        is => 'String', 
        doc => 'output in BreakDancer-esque format for input into gmt assembly tool',
    },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Prepares pipeline indels for assembly";
}

sub help_synopsis {
    return <<EOS
EOS
}

sub execute {
    $DB::single = 1;
    my $self = shift;
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($self->annotation_file);
    unless($fh) {
        $self->error_message("Unable to open annotation file");
        return;
    }

    my $ofh = IO::File->new($self->output_file,"w");
    unless($ofh) {
        $self->error_message("Unable to open output file");
        return;
    }


    #print out header
    print $ofh "#Chr1\tPos1\tOri1\tChr2\tPos2\tOri2\tType\tSize\n";

    while(my $line = $fh->getline) {
        chomp $line;
        my @fields = split /\t/, $line;
        my ($chr,$start,$end,$ref,$var,$type) = @fields[0..5];
        next if $type =~ /NP/; #skip DNP and SNP
        my $size = $ref eq '0' ? length $var : length $ref;

        print $ofh join("\t",$chr,$start,"+",$chr,$end,'+',$type,$size),"\n";
    }

    return 1;

}

1;

