package Genome::Model::Tools::Maq::GenerateVariationMetrics;

use above "Genome";

class Genome::Model::Tools::Maq::GenerateVariationMetrics {
    is => 'Genome::Model::Tools::Maq',
    has => [
        input => {
            type => 'String',
            doc => 'File path for input map',
        },
        snpfile => {
            type => 'String',
            doc => 'File path for snp file',
        },
        qual_cutoff => {
            type => 'int',
            doc => 'quality cutoff value', 
        },
        output => {
            type => 'String',
            doc => 'File path for input map', 
            is_optional => 1,
        },     
    ],
};

sub help_brief {
    "remove extra reads which are likely to be from the same fragment based on alignment start site, quality, and sequence",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt remove-pcr-artifacts orig.map new_better.map removed_stuff.map --sequence-identity-length 26
EOS
}

sub help_detail {                           
    return <<EOS 
This tool removes reads from a maq map file which are likely to be the result of PCR, rather than distinct DNA fragments.
It examines all reads at the same start site, selects the read which has the best data to represent the group based on length and alignment quality.

A future enhancement would group reads with a common sequence in the first n bases of the read and select the best read from that group.
EOS
}

sub create {
    my $class = shift;    
    my $self = $class->SUPER::create(@_);    

    return $self;
}

sub execute {
    my $self = shift;
    my $in = $self->input;
    my $snpfile = $self->snpfile;
    my $out = $self->output;

    unless ($in and $snpfile and -e $in and -e $snpfile) {
        $self->error_message("Bad params!");
        $self->usage_message($self->help_usage_complete_text);
        return;
    }
    
    my $result;
    $ovsrc =  `wtf Genome::Model::Tools::Maq::GenerateVariationMetrics_C`;
    ($ovsrc) = split /\n/,$ovsrc;
    print "This is the wtf ss wanted me to add $ovsrc\n";
    chomp $ovsrc;
    `perl $ovsrc`;#evil hack
    require Genome::Model::Tools::Maq::GenerateVariationMetrics_C;
    $result = Genome::Model::Tools::Maq::GenerateVariationMetrics_C::filter_variations($in,$snpfile, 1,$out);#$qual_cutoff);
    
    $result = !$result; # c -> perl

    $self->result($result);
    return $result;
}



1;
