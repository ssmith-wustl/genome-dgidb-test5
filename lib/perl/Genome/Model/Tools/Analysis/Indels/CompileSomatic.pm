package Genome::Model::Tools::Analysis::Indels::CompileSomatic;

#This is mostly ported from CompileBowtieResults

use strict;
use warnings;

use IO::File;
use IO::Handle;
use Genome;
require("/gscuser/dkoboldt/src/perl_modules/trunk/VarScan/VarScan/lib/VarScan/FisherTest.pm");  #using for FET. TODO move to genome model if this is going to be used

my %stats = ();

class Genome::Model::Tools::Analysis::Indels::CompileSomatic {
    is => 'Command',

    has => [
        tumor_file    => { is => 'Text', doc => "Indel results from gmt analysis indels compile-contig-counts" },
        normal_file => { is => 'Text', doc => "Indel results from gmt analysis indels compile-contig-counts" },
        output_file     => { is => 'Text', doc => "Output of indels with FET result", is_optional => 1 },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Compile the tumor and normal results into one file and calculate a p-value";
}

sub help_synopsis {
    return <<EOS
This command compiles indel counts and calculates a p-value 
EXAMPLE:	gmt analysis indels compile-somatic --tumor-file [tumor.counts.tsv] --normal-file [normal.counts.tsv]
EOS
}

sub execute {
    $DB::single = 1;
    my $self = shift;

    #check the inputs before doing any significant work
    my $tumor_fh = IO::File->new($self->tumor_file,"r");
    unless($tumor_fh) {
        $self->error_message("Unable to open ". $self->tumor_file);
        return;
    }

    my $normal_fh = IO::File->new($self->normal_file,"r");
    unless($normal_fh) {
        $self->error_message("Unable to open " . $self->normal_file);
        return;
    }

    my %indels; #hash to match up indels between files

    while(my $normal_line = $normal_fh->getline) {
        chomp $normal_line;

        my @fields = split /\t/, $normal_line;

        #generate unique identifier
        my $indel_name = uc(join("_",@fields[0..4]));

        if(exists($indels{$indel_name})) {
            $self->error_message("Multiple instances of the same indel present in file. Skipping line " . $normal_fh->input_line_number);
            next;
        }

        #store counts for later
        my ($ref, $var) = @fields[-3,-2];

        $indels{$indel_name} = {    line => $normal_line, 
                                    normal_ref => $ref,
                                    normal_var => $var,
        };
    }

    #read in tumor and calculate the p-value
    while(my $tumor_line = $tumor_fh->getline) {
        chomp $tumor_line;

        my @fields = split /\t/, $tumor_line;

        #generate unique identifier
        my $indel_name = uc(join("_",@fields[0..4]));

        unless(exists($indels{$indel_name})) {
            $self->error_message("Indel missing in the normal filei or duplicated in the tumor file. Skipping line " . $tumor_fh->input_line_number);
            next;
        }

        #store counts for later
        my $entry = $indels{$indel_name};
        my ($ref, $var) = @fields[-3,-2];

		my $p_value = VarScan::FisherTest::calculate_p_value($entry->{normal_ref}, $entry->{normal_var}, $ref, $var, 0);
        
        my $llr = 0;

        if(($entry->{normal_ref}+$entry->{normal_var}) > 0 && ($ref+$var) > 0) {
            #calculate LLR
            my $somatic_normal_expect = $entry->{normal_var}/($entry->{normal_ref}+$entry->{normal_var});
            my $not_somatic_normal_expect = 1 - $somatic_normal_expect;
            my $somatic_tumor_expect = $var/($ref+$var);
            my $not_somatic_tumor_expect = 1 - $somatic_tumor_expect;
            my $reference_expect = ($var+$entry->{normal_var})/($entry->{normal_ref}+$entry->{normal_var}+$ref+$var);
            my $not_reference_expect = 1- $reference_expect;
            $somatic_normal_expect ||= 0.001;
            $not_somatic_normal_expect ||= 0.001;
            $somatic_tumor_expect ||= 0.001;
            $not_somatic_tumor_expect ||= 0.001;
            $reference_expect ||= 0.001;
            $not_reference_expect ||= 0.001;

            my $somatic_LLR = $entry->{normal_var}*log($somatic_normal_expect) + $entry->{normal_ref}*log($not_somatic_normal_expect) + $var*log($somatic_tumor_expect) + $ref*log($not_somatic_tumor_expect);
            my $nonsomatic_LLR = $entry->{normal_var}*log($reference_expect) + $entry->{normal_ref}*log($not_reference_expect) + $var*log($reference_expect) + $ref*log($not_reference_expect);

            $llr = $somatic_LLR-$nonsomatic_LLR;
        }
        print STDOUT $entry->{line},"\t",join("\t",@fields[-4,-3,-2,-1],$p_value,$llr),"\n";
        delete $indels{$indel_name};
    }

    return 1;

}

1;

