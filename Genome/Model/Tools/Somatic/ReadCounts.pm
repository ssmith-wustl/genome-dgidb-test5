package Genome::Model::Tools::Somatic::ReadCounts;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use IO::File;
use Data::Dumper;

class Genome::Model::Tools::Somatic::ReadCounts {

    is  => ['Command'],
    has => [
       tumor_bam => {
           is => 'String',
           doc =>'is this not obvious?',
       },
       normal_bam => {
           is => 'String',
           doc =>'I don\'t mean to insult your intelligence...but really.',
       },
       sites_file => {
           is => 'String',
           doc =>'the sites of interest in annotation format. Refer to something else to figure out what that is.'
       },
       reference_sequence => {
           is => 'String',
           doc =>'defaults to NCBI-human-build36....because this is good software',
           is_optional=>1,
           default=> '/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa',
       },
       out => {
           is => 'String',
           doc =>'where the output goes',
       },
        ],
    };
    
    sub help_brief {
        return "A great tool that everyone should be using";
    }

    sub help_synopsis {
        my $self = shift;
        return <<"EOS"
        this help is less brief than brief but less detailed than detailed. and Im not telling you how to run this
EOS
    }

    sub help_detail {                           
        return <<EOS 
        I REFUSE TO GIVE YOU DETAILS ON THIS HELP
EOS
    }

    sub execute {
        my ($self) = @_;
        my ($stupid_dave_fh, $stupid_dave_format_file)  =Genome::Utility::FileSystem->create_temp_file();
        my $anno_fh = IO::File->new($self->sites_file);
        my $output_fh = IO::File->new($self->out, ">");
        unless($output_fh) {
            $self->error_message("Now is the winter of your discontent!!!");
            return 0;
        }
        unless($anno_fh) {
            $self->error_message("Unable to comply, building in progress.");
            return 0;
        }
        while (my $line = $anno_fh->getline) {
            chomp $line;
            my ($chr, $pos,) = split /\t/, $line;
            $stupid_dave_fh->print("$chr\t$pos\t$pos\n");
        }
        $stupid_dave_fh->close;
        my $normal_bam_command =  "bam-readcount -q 30 -f " .  $self->reference_sequence . " -l $stupid_dave_format_file " . $self->normal_bam;
        my $tumor_bam_command =  "bam-readcount -q 30 -f " .  $self->reference_sequence . " -l $stupid_dave_format_file " . $self->tumor_bam;
        $DB::single=1;
        my @normal_lines = `$normal_bam_command`;
        my @tumor_lines  = `$tumor_bam_command`;
        my %hash_of_arrays;
        $hash_of_arrays{'Normal'}=\@normal_lines;
        $hash_of_arrays{'Tumor'}=\@tumor_lines;
        $self->make_excel_friendly_output_sheet($output_fh, \%hash_of_arrays);
       return 1;
   }
1;   


sub make_excel_friendly_output_sheet {
    my ($self, $output_fh, $tumor_normal_hash_ref) = @_;
    my %hash_of_arrays = %{$tumor_normal_hash_ref};
    $output_fh->print("CHROM\tPOS\tREF\tVAR\tGENE\tMUTATION\t" . join("\t\t\t", sort keys %hash_of_arrays) . "\n");
    my $anno_fh = IO::File->new($self->sites_file);
    while (my $line = $anno_fh->getline) {
        chomp $line;
        my ($chrom, $pos, $foo, $ref, $var, $bstype, $gene, $transcript,
        $organism, $source, $version, $some_shit, $transcipt_status, $type, @foobar)= split /\t/, $line; #add one field before  second type to get this crap to work correctyly with new annotator
        $output_fh->print("$chrom\t$pos\t$ref\t$var\t$gene\t$type\t");

        for my $flowcell_id(sort keys %hash_of_arrays) {
            if(my ($line1, $line2) = grep( /$chrom\t$pos/, @{$hash_of_arrays{$flowcell_id}})) {
                $DB::single=1;
                my ($stats_for_var1) = ($line1 =~ m/($var\S+)/);
                my ($stats_for_ref1) = ($line1 =~ m/($ref\S+)/);
                my ($base_var1, $count_var1, ) = split /:/, $stats_for_var1;
                my ($base_ref1, $count_ref1, ) = split /:/, $stats_for_ref1;
                my $percent = 0;
                if($count_ref1 > 0 || $count_var1 > 0) {
                    $percent = $count_var1 / ($count_ref1 + $count_var1);
                }
                $output_fh->print("\t$count_ref1\t$count_var1\t$percent");
            }
            else {
                $output_fh->print("\t0\t0\t0");
            }
        }
        $output_fh->print("\n");
     }


}

