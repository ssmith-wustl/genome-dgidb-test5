package Genome::Model::Tools::Validation::AnnotationToAssemblyInput;

use strict;
use warnings;

use Genome;
use Genome::Sys;

class Genome::Model::Tools::Validation::AnnotationToAssemblyInput {
    is => 'Command',

    has => [
    annotation_file    => { 
        is => 'String', 
        doc => 'annotation output or annotator input file (needs first 6 columns from annotation output)',
    },
    output_file => { 
        is => 'String', 
        doc => 'output in BreakDancer-esque format for input into gmt assembly tool',
    },
    minimum_size => {
        is => 'Integer',
        default => 3,
        is_optional => 1,
        doc => 'the minimum size of the indel to output to the file',
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
    my $fh = Genome::Sys->open_file_for_reading($self->annotation_file);
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
        next if $line =~ /^chr/i;   #attempt to skip header lines that sneak in
        my @fields = split /\t/, $line;
        my ($chr,$start,$end,$ref,$var,$type) = @fields[0..5];
        next if $type =~ /NP/; #skip DNP and SNP
        my $size = $ref =~ /[0-]/ ? length $var : length $ref;
        next if($size < $self->minimum_size);

        print $ofh join("\t",$chr,$start,"+",$chr,$end,'+',$type,$size),"\n";
    }

    return 1;

}

1;

