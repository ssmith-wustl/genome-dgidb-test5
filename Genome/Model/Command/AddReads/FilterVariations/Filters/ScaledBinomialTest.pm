package Genome::Model::Command::AddReads::FilterVariations::Filters::ScaledBinomialTest;

use strict;
use warnings;

use Command;
use IO::File;
use Genome::DB::Schema;
use Statistics::R;

class Genome::Model::Command::AddReads::FilterVariations::Filters::ScaledBinomialTest
{
    is => 'Command',
    has => [
    experimental_metric_model_file => 
    {
        type => 'String',
        is_optional => 0,
        doc => 'File of experimental metrics for the model',
    },
    experimental_metric_normal_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => 'File of experimental metrics for the normal',
    },
    binomial_test_basename => 
    {
        type => 'String',
        is_optional => 0,
        doc => 'Basename for the output file',
    },
    ratio => 
    {
        type => 'Float',
        is_optional => 1,
        default => .13,
        doc => 'Ratio to expect between model and normal reads due to contamination (.13 by default)',
    },
    ref_seq_id => 
    {
        type => 'String',
        is_optional => 0,
        doc => 'Chromosome name or something',
    },
    two_sided_p_threshold => 
    {
        type => 'Float',
        is_optional => 1,
        default => .35,
        doc => 'Threshold below which to bin as non-skin in binomial test',
    },
    less_p_threshold => 
    {
        type => 'Float',
        is_optional => 1,
        default => .25,
        doc => 'Threshold below which to bin as non-skin in binomial test',
    }
    ],
};


#----------------------------------
sub execute {
    my $self = shift;
    unless($self->_create_r_files) {
        $self->error_message("Error creating temporary files for R");
        return;
    }
    unless($self->_calculate_p_values) {
        $self->error_message("Error running R binomial test");
        return;
    }
    unless($self->_convert_probabilities_to_snps) {
        $self->error_message("Error splitting metrics file into skin and non-skin bins");
        return;
    }
    return 1;
}
#----------------------------------

sub _create_r_files {
    my $self = shift;

    #create temporary files for R
    my $tumor_metric_file = new IO::File "< $self->experimental_metric_model_file";
    unless(defined($tumor_metric_file)) {
        $self->error_message("Couldn't open " . $self->experimental_metric_model_file);
        return;
    }
    my $normal_metric_file = new IO::File "< $self->experimental_metric_normal_file";
    unless(defined($normal_metric_file)) {
        $self->error_message("Couldn't open " . $self->experimental_metric_normal_file);
        return;
    }
    my $chromosome = $self->ref_seq_id;

    my $ratio = $self->ratio;

    my $r_handle = new IO::File "> /tmp/skin_binom_test_chr$chromosome.csv";
    unless(defined($r_handle)) {
        $self->error_message("Couldn't open /tmp/skin_binom_test_chr$chromosome.csv for temporary R file");
        return;
    }

    #print header
    print $r_handle "skin_variant total_variant expected_proportion\n";

    my ($line,$skin_line);

    while(($line = $tumor_metric_file->getline) && ($skin_line = $normal_metric_file->getline)) {
        chomp $line;
        chomp $skin_line;
        if($line =~ /^chromosome/) {
            $line = $tumor_metric_file->getline;   #don't check additional headers that may have been included by cat
            chomp $skin_line;
        }
        if($skin_line =~ /^chromosome/) {
            $normal_metric_file->getline;
            chomp $skin_line;
        }
        my @data_indices = (0, 1, 2, 3, 5, 24); 
        my @tumor_metrics = split ", ", $line;
        my @skin_metrics = split ", ", $line;


        my ($chr,
            $position,
            $al1,
            $al2,
            $al2_read_hg,
            $ref_read_hg,
        ) = @tumor_metrics[@data_indices];

        my ($skin_chr,
            $skin_position,
            $skin_al1,
            $skin_al2,
            $skin_al2_read_hg,
            $skin_ref_read_hg,
        ) = @skin_metrics[@data_indices];

        if($skin_chr ne $chr || $skin_position ne $position || $skin_al1 ne $al1 || $skin_al2 ne $al2) {
            #FILES ARE OFF
            #
            #Probably the skin site didn't make it through filtering
            if($skin_chr eq $chr && $skin_position > $position) {
                $self->error_message("Files de-synced during R data file creation");
            }
            else {
                $skin_line = $normal_metric_file->getline;
                redo;
            }
        }

        my $tumor_proportion = 1 - $ratio;
        my $tumor_coverage = $al2_read_hg + $ref_read_hg;
        my $skin_coverage = $skin_al2_read_hg + $skin_ref_read_hg;

        my $coverage_adjusted_proportion = $ratio * $skin_coverage / ($ratio * $skin_coverage + $tumor_proportion * $tumor_coverage);

        print $r_handle "$chr.$position.$al2 $skin_al2_read_hg ", $skin_al2_read_hg + $al2_read_hg, " $coverage_adjusted_proportion\n";  
    }
}

#----------------------------------
sub _calculate_p_values {
    my $self = shift;

    #TODO CHARRIS use %INC to find R-script path
    #get absolute path to current R-code
    # my $r_code_path;
    #
    my $chromosome = $self->ref_seq_id;
    my $snp_file_path = "/tmp/skin_binom_test_chr$chromosome.csv";


    #run the binomial test through R
    my $R_bridge = Statistics::R->new();
    unless(defined($R_bridge)) {
        $self->error_message("Couldn't access R via Statistics::R");
        return;
    }
    $R_bridge->startR();
    $R_bridge->send(qq{source("/gscuser/dlarson/src/perl-modules/trunk/test_project/dlarson/decision_tree/binomial_test.R")});
    $R_bridge->send(qq{aml.epithelial_test(infile="$snp_file_path",outfile="/tmp/skin_binom_test_chr$chromosome.less",alt="less")});
    $R_bridge->send(qq{aml.epithelial_test(infile="$snp_file_path",outfile="/tmp/skin_binom_test_chr$chromosome.two_sided",alt="two.sided")});
    $R_bridge->stopR();
}

#-----------------------------------
sub _convert_probabilities_to_locations {
    my ($self,$file,$threshold,$hash_ref) = @_;
    if(!defined($hash_ref)) {
        return;
    }
    my $snp_filename = $self->experimental_metric_model_file;

    my $handle = new IO::File "< $file";
    unless(defined($handle)) {
        $self->error_message("Couldn't open R t-test output file $file");
        return;
    }

    my $header_line = $handle->getline; #ignore header
    while(my $line = $handle->getline) {
        chomp $line;
        my ($pos_str,
            $skin_reads,
            $total_reads,
            $expected_ratio,
            $p,
        ) = split "\t", $line;
        if($p <= $threshold || $skin_reads == 0) { 
            my ($chr,$pos,$var) = split /\./,  $pos_str;
            $hash_ref->{$chr}{$pos}{$var}=1;
        }
    }
    $handle->close;
    return 1;
}

    

#----------------------------------
sub _convert_probabilities_to_snps {
    my ($self) = @_;
    my $snp_filename = $self->experimental_metric_model_file;
    my $chromosome = $self->ref_seq_id; 
    my $output = $self->binomial_test_basename;
    #expects both the two-sided and one-sided(less) tests to be present

    my %positions;
    my $result = $self->_convert_probabilities_to_locations("/tmp/skin_binom_test_chr$chromosome.less", $self->less_p_threshold,\%positions);
    unless(defined($result)) {
        $self->error_message("Error creating locations for /tmp/skin_binom_test_chr$chromosome.less");
        return;
    }
    $result = $self->_convert_probabilities_to_locations("/tmp/skin_binom_test_chr$chromosome.two_sided", $self->two_sided_p_threshold,\%positions);    
    unless(defined($result)) {
        $self->error_message("Error creating locations for /tmp/skin_binom_test_chr$chromosome.two_sided");
        return;
    }
    #at this point, all the non-skin positions should be in %positions

    my $snp_file = new IO::File "< $snp_filename";
    unless(defined($snp_file)) {
        $self->error_message("Couldn't open metrics file $snp_filename for splitting");
        return;
    }

    my $non_skin_output_handle = new IO::File "> $output.nonskin.csv";
    unless(defined($non_skin_output_handle)) {
        $self->error_message("Couldn't open $output.nonskin.csv for writing");
        return;
    }
    
    my $skin_output_handle = new IO::File "> $output.skin.csv";
    unless(defined($skin_output_handle)) {
        $self->error_message("Couldn't open $output.skin.csv for writing");
        return;
    }

    print $non_skin_output_handle $snp_file->getline; #get header and print
    print $skin_output_handle $snp_file->getline; #get header and print

    while(my $line=$snp_file->getline) {
        chomp $line;
        my ($chr,
            $position,
            $al1,
            $al2,
        ) = split ", ", $line;
        #nonskin
        if(exists($positions{$chr}) && exists($positions{$chr}{$position}) && exists($positions{$chr}{$position}{$al2})) {
            print $non_skin_output_handle $line,"\n";
        }
        else {
            print $skin_output_handle $line, "\n";
        }
    }
}

sub DESTROY {
    my $self = shift;
    #unlink all temporary files
    #TODO CHARRIS Add a class variable to track the files to unlink and unlink them here.   
} 
